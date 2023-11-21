
resource "kubectl_manifest" "default_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      blockDeviceMappings:
      - deviceName: /dev/xvda
        ebs:
          volumeSize: 4Gi
          volumeType: gp3
          encrypted: true
      - deviceName: /dev/xvdb
        ebs:
          volumeSize: 20Gi
          volumeType: gp3
          encrypted: true
      amiFamily: Bottlerocket
      userData: |
        # The admin host container provides SSH access and runs with "superpowers".
        # It is disabled by default, but can be disabled explicitly.
        [settings.host-containers.admin]
        enabled = false

        # The control host container provides out-of-band access via SSM.
        # It is enabled by default and can be disabled if you do not expect to use SSM.
        # This could leave you with no way to access the API and change settings on an existing node!
        [settings.host-containers.control]
        enabled = true

        # Extra kernel settings
        [settings.kernel]
        lockdown = "integrity"

        [settings.kernel.modules.udf]
        allowed = false

        [settings.kernel.modules.sctp]
        allowed = false

        [settings.kernel.sysctl]
        # 3.1.1
        "net.ipv4.conf.all.send_redirects" = "0"
        "net.ipv4.conf.default.send_redirects" = "0"

        # 3.2.2
        "net.ipv4.conf.all.accept_redirects" = "0"
        "net.ipv4.conf.default.accept_redirects" = "0"

        #Removing these two as EKS running on ipv6 mode, 
        #routing needs to accept redirects else commands like exec, health check doesn't work
        #"net.ipv6.conf.all.accept_redirects" = "0"
        #"net.ipv6.conf.default.accept_redirects" = "0"

        # 3.2.3
        "net.ipv4.conf.all.secure_redirects" = "0"
        "net.ipv4.conf.default.secure_redirects" = "0"

        # 3.2.4
        "net.ipv4.conf.all.log_martians" = "1"
        "net.ipv4.conf.default.log_martians" = "1"


        [settings.kubernetes]
        "ip-family" = "ipv6"
        "service-ipv6-cidr" = "fd2b:2fa9:d746::/108"

        [settings.bootstrap-containers.cis-bootstrap]
        source = "776633114724.dkr.ecr.ap-south-1.amazonaws.com/bottlerocket-bootstrap:main-bottlerocket-bootstrap-123"
        mode = "always"
      subnetSelector:
        karpenter.sh/discovery: ${module.stage1_eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.stage1_eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.stage1_eks.cluster_name}
        sprinto: Stage
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}




resource "kubectl_manifest" "karpenter_provisioner_spot_mix" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: spot-mix
    spec:
      # References cloud provider-specific custom resource, see your cloud provider specific documentation
      providerRef:
        name: default

      # Provisioned nodes will have these taints
      # Taints may prevent pods from scheduling if they are not tolerated by the pod.
      #taints:
      #  - key: example.com/special-taint
      #    effect: NoSchedule

      # Provisioned nodes will have these taints, but pods do not need to tolerate these taints to be provisioned by this
      # provisioner. These taints are expected to be temporary and some other entity (e.g. a DaemonSet) is responsible for
      # removing the taint after it has finished initializing the node.
      #startupTaints:
      #  - key: example.com/another-taint
      #    effect: NoSchedule

      # Labels are arbitrary key-values that are applied to all nodes
      labels:
        lifecycle: spot
        workloadAffinity: mix
        workloadType: continuous


      # Annotations are arbitrary key-values that are applied to all nodes
      #annotations:
      #  example.com/owner: "my-team"

      # Requirements that constrain the parameters of provisioned nodes.
      # These requirements are combined with pod.spec.affinity.nodeAffinity rules.
      # Operators { In, NotIn, Exists, DoesNotExist, Gt, and Lt } are supported.
      # https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#operators
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["t", "m"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["1", "2", "4"]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: Gt
          values: ["4"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ["ap-south-1a"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["spot"]

      # Karpenter provides the ability to specify a few additional Kubelet args.
      # These are all optional and provide support for additional customization and use cases.
      kubeletConfiguration:
        clusterDNS: ["fd2b:2fa9:d746::a"]
        containerRuntime: containerd
        systemReserved:
        cpu: 100m
        memory: 100Mi
        ephemeral-storage: 1Gi
        kubeReserved:
          cpu: 200m
          memory: 100Mi
          ephemeral-storage: 3Gi
        evictionHard:
          memory.available: 5%
          nodefs.available: 10%
          nodefs.inodesFree: 10%
        evictionSoft:
          memory.available: 500Mi
          nodefs.available: 15%
          nodefs.inodesFree: 15%
        evictionSoftGracePeriod:
          memory.available: 1m
          nodefs.available: 1m30s
          nodefs.inodesFree: 2m
        evictionMaxPodGracePeriod: 60
        imageGCHighThresholdPercent: 85
        imageGCLowThresholdPercent: 80
        cpuCFSQuota: true
        maxPods: 20


        # Resource limits constrain the total size of the cluster.
        # Limits prevent Karpenter from creating new instances once the limit is exceeded.
        limits:
          resources:
            cpu: "10"
            memory: 50Gi

        # Enables consolidation which attempts to reduce cluster cost by both removing un-needed nodes and down-sizing those
        # that can't be removed.  Mutually exclusive with the ttlSecondsAfterEmpty parameter.
        consolidation:
          enabled: true

        # If omitted, the feature is disabled and nodes will never expire.  If set to less time than it requires for a node
        # to become ready, the node may expire before any pods successfully start.
        ttlSecondsUntilExpired: 2592000 # 30 Days = 60 * 60 * 24 * 30 Seconds;

        # If omitted, the feature is disabled, nodes will never scale down due to low utilization
        ttlSecondsAfterEmpty: 30

        # Priority given to the provisioner when the scheduler considers which provisioner
        # to select. Higher weights indicate higher priority when comparing provisioners.
        # Specifying no weight is equivalent to specifying a weight of 0.
        weight: 10
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}