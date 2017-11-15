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

  echo 1 - Building image called: $S3_NAME from $DOCKERFILE_NAME

  docker build ./ -t $S3_NAME -f $DOCKERFILE_NAME

  echo 2 - Getting containder id

  CONTAINER_ID=$(docker run -d -p 8000:8000 ${S3_NAME})

  echo 3 - CONTAINER_ID = $CONTAINER_ID

  echo 3.0 - Sleep 20 seconds

  sleep 20

  echo 3.1 - Listing bucket

  LIST_BUCKETS=$(aws --profile=local --endpoint-url=http://localhost:8000 s3 ls)

  echo 3.2 - LIST_BUCKETS = $LIST_BUCKETS

  MAKE_BUCKET=$(aws --profile=local --endpoint-url=http://localhost:8000 s3 mb s3://mybucket)

  echo 4 -  MAKE_BUCKET = $MAKE_BUCKET

  if [ "$MAKE_BUCKET" != "make_bucket: mybucket" ]; then
      echo ERROR - unable to create bucket: $MAKE_BUCKET
      docker stop $CONTAINER_ID
      exit 1
  fi

  echo 5 - Stopping Docker container $CONTAINER_ID

  docker stop $CONTAINER_ID

  echo 6 - Replacing tag from "$S3_NAME" to "scality/s3server"

  docker tag $S3_NAME scality/s3server:${TAG}latest

  echo 7 - Pushing image scality/s3server:${TAG}latest

  docker push scality/s3server:${TAG}latest

  echo 8 - Replacing tag from $S3_NAME to scality/s3server:${TAG}${SHORT_HASH}

  docker tag $S3_NAME scality/s3server:${TAG}${SHORT_HASH}

  echo 9 - Pushing image scality/s3server:${TAG}${SHORT_HASH}

  docker push scality/s3server:${TAG}${SHORT_HASH}

}

clean() {
    docker stop $(docker ps -a -q)
    docker rm $(docker ps -a -q)
    docker rmi $(docker images -q) -f
    rm -rf s3
}

clear
clean

git clone https://github.com/scality/s3

cd s3

# Build file and memory Docker image

echo Starting building the file Docker image

build_image "file"

# Build the memory image

echo Starting building the memory Docker image

build_image "mem"

clean
