// const Diff = require('diff')

// word1="ankits"
// word2="ankits"

// result=Diff.diffWords(word1, word2);


// for (let i = 0; i < result.length; i++) {
//     if ("added" in result[i] || "removed" in result[i]) {
//         console.log("Changed")
//     }
//     else {
//         console.log("Nothing changed")
//     }
//   }

// const fun = async function() {
//     const AWS = require('aws-sdk')
//     AWS.config.region = "ap-south-1"
//     const s3 = new AWS.S3()
//     oldVersion =   {
//         ETag: '"79e1dda7afa61fd80bf226a7360a2606"',
//         ChecksumAlgorithm: [],
//         Size: 5,
//         StorageClass: 'STANDARD',
//         Key: 'ppp',
//         VersionId: '9XwU.F7fzLIY2f7P7OQSgrBCidH6d3DA',
//         IsLatest: false,
//         VersionNumber: 8,
//         BucketName: 'ups-uat-loki'
//       }

//       newVersion =   {
//         ETag: '"0d429d90795f3cb2b621d4bd201c1a02"',
//         ChecksumAlgorithm: [],
//         Size: 5,
//         StorageClass: 'STANDARD',
//         Key: 'ppp',
//         VersionId: '2qQfPNQMAREEHak16x7wW2DIjOvFHWIP',
//         IsLatest: true,
//         VersionNumber: 9,
//         BucketName: 'ups-uat-loki'
//       }

//       try {

//     const result = await s3.getObject({ Bucket: oldVersion.BucketName, Key: oldVersion.Key, VersionId: oldVersion.VersionId }).promise()
//     console.log(result)
//       } catch (e) {

//     console.log(result)
//       }
//     // const result = await s3.getObject({ Bucket: newVersion.BucketName, Key: newVersion.Key, versionId: newVersion.versionId }).promise()
// }

const fun = async function() {
     const AWS = require('aws-sdk')
     AWS.config.region = "ap-south-1"
    var sns = new AWS.SNS();
    var snsParams = {
        Message: "TEst",
        Subject: "S3 FIM Alert",
        TopicArn: "arn:aws:sns:ap-south-1:133459798589:aws-controltower-AggregateSecurityNotifications"
    };

    const data = await sns.publish(snsParams, async function (err, data) {
        if (err) {
            console.log("SNS Push Failed:");
            console.log(err.stack);
            return;
        }
        console.log('SNS push suceeded: ' + data);
        return data;
    }).promise();
}
fun()