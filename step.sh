#!/bin/bash

THIS_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${THIS_SCRIPTDIR}/_bash_utils/utils.sh"
source "${THIS_SCRIPTDIR}/_bash_utils/formatted_output.sh"

write_section_start_to_formatted_output "# Retriving project id"
if [ -z "$gitlab_project_id" ]; then
  gitlab_project_id=`curl -sS -H "PRIVATE-TOKEN: ${gitlab_private_token}" "${gitlab_api_url}/projects/owned" | jq --arg repo "${gitlab_project_repo}" '.[] | select(.path_with_namespace == $repo).id'`
fi

if [ -z "$gitlab_project_id" ]; then
  write_section_to_formatted_output "# Error"
  write_section_start_to_formatted_output '* Invalid project id'
  exit 1
fi
write_section_start_to_formatted_output "## ${gitlab_project_repo} id is ${gitlab_project_id}"

write_section_start_to_formatted_output "# Retriving builds"
gitlab_build=`curl -sS -H "PRIVATE-TOKEN: ${gitlab_private_token}" "${gitlab_api_url}/projects/${gitlab_project_id}/builds" | jq -r --arg ref "${gitlab_build_branch}" --arg stage "${gitlab_build_stage}" --arg name "${gitlab_build_name}" 'map(select(.status == "success" and .artifacts_file != null)) | if $ref != "" then map(select(.ref == $ref)) else . end | if $stage != "" then map(select(.stage == $stage)) else . end | if $name != "" then map(select(.name == $name)) else . end | max_by(.id)'`

if [ -z "$gitlab_build" -o "$gitlab_build" == "null" ]; then
  write_section_to_formatted_output "# Error"
  write_section_start_to_formatted_output '* Invalid build'
  exit 1
fi

write_section_start_to_formatted_output "## Build info:"
echo "$gitlab_build" | jq '.'

gitlab_build_id=`echo "$gitlab_build" | jq '.id'`
gitlab_artifact_file_name=`echo "$gitlab_build" | jq '.artifacts_file.filename' | cut -d'"' -f2`
gitlab_artifact_file_name="${gitlab_build_id}-${gitlab_artifact_file_name}"

gitlab_artifact_temp_dir="$BITRISE_CACHE_DIR/GitlabArtifacts"
if [ ! -f "${gitlab_artifact_temp_dir}/${gitlab_artifact_file_name}" ]; then
  rm -rf "${gitlab_artifact_temp_dir}"
  mkdir -p "${gitlab_artifact_temp_dir}"
  write_section_start_to_formatted_output "# Downloading ${gitlab_artifact_file_name}"
  curl -sS -H "PRIVATE-TOKEN: ${gitlab_private_token}" "${gitlab_api_url}/projects/${gitlab_project_id}/builds/${gitlab_build_id}/artifacts" > "${gitlab_artifact_temp_dir}/${gitlab_artifact_file_name}"

  if [ $? -ne 0 ]; then
    write_section_to_formatted_output "# Error"
    write_section_start_to_formatted_output '* Failed to download artifacts'
    exit 1
  fi
fi

if [[ "${gitlab_artifact_file_name}" == *.zip ]]; then
  write_section_start_to_formatted_output "## Unzipping ${gitlab_artifact_file_name} to ${gitlab_artifacts_path}"
  unzip -o "${gitlab_artifact_temp_dir}/${gitlab_artifact_file_name}" -d "${gitlab_artifacts_path}"
fi

exit 0
