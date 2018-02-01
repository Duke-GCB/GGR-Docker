#!/bin/bash

# This build needs to determine what files changed in the most recent commit.
# git diff-tree does not show file name changes for merge commits
function last_nonmerge_commit_sha() {
  git log --no-merges -n 1 --format="%H"
}

# Given an SHA1 hash, produce the list of file paths changed in that commit
function changed_paths_in_commit() {
  sha=$1
  git diff-tree --no-commit-id --name-only -r $sha
}

# Given a docker repo owner, image name, and version, produce a local docker build command
function build_docker_cmd() {
  owner=$1
  tool=$2
  version=$3
  echo "docker build -f $tool/$version/Dockerfile" -t "$owner/$tool:$version" "$tool/$version"
}

# Given a docker repo owner, image name, and version, produce a docker push command
function push_docker_cmd() {
  owner=$1
  tool=$2
  version=$3
  echo "docker push $owner/$tool:$version";
}

# Given a docker repo owner, image name, source and dest tags produce a docker tag command
tag_docker_cmd() {
  owner=$1
  tool=$2
  src=$3
  tag=$4
  echo "docker tag $owner/$tool:$version $owner/$tool:$tag"
}

# Given
# 1. a Docker repo owner (e.g. "dukegcb") and
# 2. a list of relative paths to Dockerfiles (e.g. "fastqc/0.11.4/Dockerfile bwa/0.7.12/Dockerfile",
# issue a docker build command and tag any versions with a latest symlink
function build_images() {
  owner="$1"
  changed_paths="$2"
  for changed_path in $changed_paths; do
    IFS='/' read -r -a f <<< "$changed_path"
    tool="${f[0]}"
    version="${f[1]}"
    filename="${f[2]}"
    if [[ "$filename" == "Dockerfile" && "$version" != "latest" ]]; then
      attempted_build="1"
      echo "Building $owner/$tool:$version..."
      $(build_docker_cmd $owner $tool $version)
      # Check if there's a symlink $tool/latest pointing to THIS version
      if [[ "$tool/latest/Dockerfile" -ef "$tool/$version/Dockerfile" ]]; then
        echo "Tagging $owner/$tool:$version as $owner/$tool:latest"
        $(tag_docker_cmd $owner $tool $version "latest")
      fi
    fi
  done;
  if [[ "$attempted_build" == "" ]]; then
    echo "No changes to a Dockerfile detected, skipping build";
  fi
}

# Given
# 1. a Docker repo owner (e.g. "dukegcb") and
# 2. a list of relative paths to Dockerfiles (e.g. "fastqc/0.11.4/Dockerfile bwa/0.7.12/Dockerfile",
# issue a docker push command for the images built by build_images
function push_images() {
  owner="$1"
  changed_paths="$2"
  for changed_path in $changed_paths; do
    IFS='/' read -r -a f <<< "$changed_path"
    tool="${f[0]}"
    version="${f[1]}"
    filename="${f[2]}"
    if [[ "$filename" == "Dockerfile" && "$version" != "latest" ]]; then
      attempted_push="1"
      echo "Pushing $owner/$tool:$version..."
      $(push_docker_cmd $owner $tool $version)
      # Check if there's a symlink $tool/latest pointing to THIS version
      if [[ "$tool/latest/Dockerfile" -ef "$tool/$version/Dockerfile" ]]; then
        echo "Pushing $owner/$tool:latest..."
        $(push_docker_cmd $owner $tool "latest")
      fi
    fi
  done;
  if [[ "$attempted_push" == "" ]]; then
    echo "No changes to a Dockerfile detected, skipping push";
  fi
}

function print_changed() {
  sha="$1"
  paths="$2"
  echo "Changed files in $sha:"
  echo
  for changed_path in $paths; do
    echo "  $changed_path"
  done
  echo
  echo "Building changed Dockerfiles..."
  echo
}

function check_org() {
  if [[ "$DOCKERHUB_ORG" == "" ]]; then
    echo "Error: DOCKERHUB_ORG is empty"
    echo "Please ensure DOCKERHUB_ORG is set to the name of the Docker Hub organization";
    exit 1;
  else
    echo "Using Docker Hub org as $DOCKERHUB_ORG..."
  fi
}
