/*! Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *  SPDX-License-Identifier: MIT-0
 */

'use strict'

const { compareS3 } = require('./compareS3')
const { deleteS3 } = require('./deleteS3')

const AWS = require('aws-sdk')
AWS.config.region = "ap-south-1"
const s3 = new AWS.S3()

const processS3 = async (record) => {
  try {
    // Decode URL-encoded key
    const Key = decodeURIComponent(record.s3.object.key.replace(/\+/g, " "))

    // Get the list of object versions
    const data = await s3.listObjectVersions({
      Bucket: record.s3.bucket.name,
      Prefix: Key
    }).promise()

    console.log (JSON.stringify(data, null, 2))
    
   // Sort versions by date (ascending by LastModified)
    const versions = data.Versions
  
    


    const notificationFileChange = async function(diffResult) {
      var fileChanged = false
      for (let i = 0; i < diffResult.length; i++) {
        if ("added" in diffResult[i] || "removed" in diffResult[i]) {
            console.log("Changed")
            fileChanged = true
            break;
        }
      }
   
  
  
      var sns = new AWS.SNS();
   
      var fileChangeNotification = {
        "bucketName": record.s3.bucket.name,
        "key": Key,
        "Diff": diffResult
  
      }
  
      var snsParams = {
        Message: JSON.stringify(fileChangeNotification),
        Subject: "S3 FIM Alert",
        TopicArn: process.env.SNS_NOTIFICATION_TOPIC
    };
   
    if (fileChanged) {
      console.log(fileChangeNotification)
     
        console.log("Trying to send the sns notification")
        const data = await sns.publish(snsParams, async function (err, data) {
          if (err) {
              console.log("SNS Push Failed:");
              console.log(err.stack);
              return;
          }
          console.log('SNS push suceeded: ' + data);
          return data;
      }).promise();
    } else {
        console.log("Nothing Changed")
    }
  
    }
  

    if (versions.length > 1) {
      const sortedVersions = versions.sort((a,b) => new Date(a.LastModified) - new Date(b.LastModified))

      // Add version number
      for (let i = 0; i < sortedVersions.length; i++) {
        sortedVersions[i].VersionNumber = i + 1
        sortedVersions[i].BucketName = record.s3.bucket.name
      }
      console.log(sortedVersions)
    // Get diff of last two versions
    const result = await compareS3(sortedVersions[sortedVersions.length - 2], sortedVersions[sortedVersions.length - 1])
    console.log('Diff: ', result)
    await notificationFileChange(result)
    }
 

    // // Only continue there are more versions that we should keep
    // if (data.Versions.length <= process.env.KEEP_VERSIONS) {
    //   return console.log("Not enough versions for deletion - exit")
    // }

    // // Delete older versions
    // await deleteS3(sortedVersions)


    
  } catch (err) {
    console.error(err)
  }
}

module.exports = { processS3 }


