#!/bin/bash

build_image() {

  if [ "$1" ]; then

      if [ "$1" = "file" ]; then
          S3_NAME="s3"
          DOCKERFILE_NAME="Dockerfile"
          TAG=""
      elif [ "$1" = "mem" ]; then
          S3_NAME="s3mem"
          DOCKERFILE_NAME="DockerfileMem"
          TAG="mem-"
      else
          echo ERROR - parameter passed is neither "mem" or "file"
          exit 1
      fi

  else

      echo ERROR - no parameter passed
      exit 1
      
  fi

  SHORT_HASH=$(git rev-parse --short HEAD)

  docker build ./ -t $S3_NAME -f $DOCKERFILE_NAME

  echo Testing the build

  CONTAINER_ID=$(docker run -d -p 8000:8000 ${S3_NAME})

  MAKE_BUCKET=$(aws --profile=local --endpoint-url=http://localhost:8000 s3 mb s3://mybucket)

  if [ "$MAKE_BUCKET" != "make_bucket: s3://mybucket/" ]; then
      echo ERROR - unable to create bucket: $MAKE_BUCKET
      docker stop $S3_NAME
      exit 1
  fi

  docker stop $CONTAINER_ID

  echo changing tag from "$S3_NAME" to "scality/s3server"

  # docker tag s3 scality/s3server
  docker tag $S3_NAME nicolas2bert/tests3server:${TAG}latest

  # docker push scality/s3server
  docker push nicolas2bert/tests3server:${TAG}latest

  # docker tag s3 scality/s3server:
  docker tag $S3_NAME nicolas2bert/tests3server:${TAG}${SHORT_HASH}

  # docker push scality/s3server:GIT_HASH_TAG
  docker push nicolas2bert/tests3server:${TAG}${SHORT_HASH}

}

clear

docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)
docker rmi $(docker images -q) -f
rm -rf s3

git clone https://github.com/scality/s3

cd s3

# Build file and memory Docker image

echo Starting building the file Docker image

build_image "file"

# Build the memory image

echo Starting building the memory Docker image

build_image "mem"
