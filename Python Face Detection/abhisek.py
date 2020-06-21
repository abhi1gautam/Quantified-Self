# This script uses S3 bucket to retrieve images and feeds them to Azure's face detection API

import requests
import json
from os import listdir
import time
import pandas as pd
import re

# set to your own subscription key value to get files from S3 bucket
subscription_key = '76144212912e4fc7a3ea5378a79a286e'
assert subscription_key
image_list = listdir('abhisek_photos')

df = pd.DataFrame(columns=['Image Name', 'Date', 'Time',
	'Anger', 'Contempt', 'Disgust',
	'Fear', 'Happiness', 'Neutral',
	'Sadness', 'Surprise'])


# replace <My Endpoint String> with the string from your endpoint URL
face_api_url = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/detect'

image_folder_url = 'https://mdsi-innodata.s3-ap-southeast-2.amazonaws.com/Abhisek/'

headers = {'Ocp-Apim-Subscription-Key': subscription_key}

params = {
    'returnFaceId': 'true',
    'returnFaceLandmarks': 'false',
    'returnFaceAttributes': 'age,emotion',
}

i=0

#loop over the images
for image_file in image_list:
	if image_file.endswith(".jpg"):

		image_date = re.split("_", image_file)[1]

		print(image_file)

		image_time = re.split('\.', re.split("_", image_file)[2])[0]

		image_url= str(image_folder_url + image_file)

		response = requests.post(face_api_url, params=params,
		                         headers=headers, json={"url": image_url})
		data = json.dumps(response.json())

		if json.loads(data):
			res = json.loads(data)[0]


			# print(res.get("faceAttributes").get("emotion"))

			# print(res.get("faceAttributes").get("emotion").get("sadness"))

			df.loc[i] = [image_file]+ [image_date] + [image_time] + [res.get("faceAttributes").get("emotion").get("anger")] + [res.get("faceAttributes").get("emotion").get("contempt")] + [res.get("faceAttributes").get("emotion").get("disgust")] + [res.get("faceAttributes").get("emotion").get("fear")] + [res.get("faceAttributes").get("emotion").get("happiness")] + [res.get("faceAttributes").get("emotion").get("neutral")] + [res.get("faceAttributes").get("emotion").get("sadness")] + [res.get("faceAttributes").get("emotion").get("surprise")]

			i = i + 1

		else:
			print(image_file + "could not be calculated. Error!!!")

		time.sleep(7)

df1 = df.sort_values('Image Name', ascending = True)
df1.to_excel('dict1.xlsx')
