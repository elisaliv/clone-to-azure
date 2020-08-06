#!/bin/bash
# Elisa Aliverti-Piuri, 6-Aug-2020

# You need to have azure-cli installed to run this script

# Gitlab URLs and azure project name
apiurl="https://gitlab.com/api/v4/groups/<name>"
sourceurl="https://gitlab.com/<name>/"
azproject="<name>"

# Files to store repos' names in
projects="gitlab_projects.txt"
subgroups="gitlab_subgroups.txt"
subprojects="gitlab_subprojects.txt"

set -e

# Change this variable to 0 if you want the script to run non-interactively
user_consent=1

# Interactive function for [Y/n] checks
function assert_consent {
    if [[ $2 -eq 0 ]]; then
        return 0
    fi

    echo -n "$1 [Y/n] "
    read consent
    if [[ ! "${consent}" =~ ^[Yy]$ && ! "${consent}" == "" ]]; then
        echo "OK, bye!"
        exit 1
    fi
}

# Get all gitlab projects' names via API (projects in subgroups are not included)
curl -s $apiurl | sed "s/,/\n/g" | grep -e 'http_url_to_repo*' | \
	cut -d'/' -f5 | cut -d'.' -f1 > $projects

# Check if the result looks right
nlines=$(wc -l < $projects)
fhead=$(head $projects)
printf "I have found $nlines repos, for example:\n$fhead\n"
assert_consent "Do you want to proceed?" ${user_consent}

# Create azure repos and import from gitlab
for repo in `cat $projects`; do
	# Name of azure repo
	reponame="data_${repo}"
	printf "Process start for $repo\n"
        az repos create --name $reponame --project $azproject -o none
        printf "Successfully created repo $reponame\n"
        az repos import create --git-source-url $sourceurl$repo".git" \
                --project $azproject --repository $reponame -o table
        printf "Successfully imported repo $repo from gitlab\n"
done

# Get all subgroups' names
curl -s $apiurl/"subgroups" | sed "s/,/\n/g" | grep -e 'full_path*' | \
	cut -d'/' -f2 | cut -d'"' -f1 > $subgroups

# Check if the result looks right
nlines=$(wc -l < $subgroups)
fcat=$(cat $subgroups)
printf "I have found $nlines subgroups:\n$fcat\n"
assert_consent "Do you want to proceed?" ${user_consent}

# Get all subgroups' projects names, create azure repos and import
for subgroup in `cat $subgroups`; do
	curl -s $apiurl"%2f"$subgroup | sed "s/,/\n/g" | grep -e 'http_url_to_repo*' | \
		cut -d'/' -f6 | cut -d'.' -f1 > $subprojects
	for repo in `cat $subprojects`; do
		# Name of azure repo (truncate if longer than 64 characters)
		reponame=$(cut -c1-64 <<< "data_${subgroup}_${repo}")
		printf "Process start for $subgroup/$repo\n"
		az repos create --name $reponame --project $azproject -o none
        	printf "Successfully created repo $reponame\n"
        	az repos import create --git-source-url $sourceurl$subgroup"/"$repo".git" \
                	--project $azproject --repository $reponame -o table
        	printf "Successfully imported repo $subgroup/$repo from gitlab\n"
	done
done
