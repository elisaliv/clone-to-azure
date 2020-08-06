#!/bin/bash
# Elisa Aliverti-Piuri, 6-Aug-2020

# You need to have azure-cli installed to run this script

# Github URLs and azure project name
apiurl="https://api.github.com/orgs/<name>/repos?per_page=50"
sourceurl="https://github.com/<name>/"
azproject="<name>"

# File to store repos' names in
repos="github_repos.txt"

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


# Get all github repos' names via API
curl -s $apiurl | grep -e 'git_url*' | cut -d'/' -f5 | cut -d'.' -f1 > $repos

# Check if the result looks right
nlines=$(wc -l < $repos)
fhead=$(head $repos)
printf "I have found $nlines repos, for example:\n$fhead\n"
assert_consent "Do you want to proceed?" ${user_consent}

# Create azure repos and import from github
for repo in `cat $repos`; do 
	printf "Process start for $repo\n"
	az repos create --name $repo --project $azproject -o none
	printf "Successfully created repo $repo\n"
	az repos import create --git-source-url $sourceurl$repo \
		--project $azproject --repository $repo -o table
	printf "Successfully imported repo $repo from github\n"
done
