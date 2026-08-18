#!/usr/bin/env bash
# shellcheck shell=bash

set -o errexit
set -o pipefail
set -o xtrace

exec 1>&2

function setup_apt {
	export DEBIAN_FRONTEND=noninteractive
}

function cleanup_apt {
	apt-get clean
	apt-get autoremove --purge --yes
	rm -rf /var/lib/apt/lists/*
}

function update_and_upgrade_apt {
	apt-get update --yes
	apt-get upgrade --yes
}

function install_packages {
	sudo apt-get install -y ansible
	ansible-galaxy collection install community.general
}

function install_nix() {
	curl -L https://releases.nixos.org/nix/nix-2.34.6/install | sh -s -- --yes --daemon --nix-extra-conf-file <(
		cat <<-EOF
			always-allow-substitutes = true
			extra-experimental-features = nix-command flakes
			extra-substituters = https://nix-postgres-artifacts.s3.amazonaws.com
			extra-trusted-public-keys = nix-postgres-artifacts:dGZlQOvKcNEjvT7QEAJbcV6b6uk7VF/hWMjhYleiaLI=
		EOF
	)

	#shellcheck disable=SC1091
	. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
	nix --version
}

function execute_stage2_playbook {
	echo "POSTGRES_MAJOR_VERSION: $POSTGRES_MAJOR_VERSION"
	echo "GIT_SHA: $GIT_SHA"
	mkdir -p /etc/ansible
	tee /etc/ansible/ansible.cfg <<-EOF
		[defaults]
		callbacks_enabled = timer, profile_tasks, profile_roles
	EOF
	sed -i 's/- hosts: all/- hosts: localhost/' /tmp/ansible-playbook/ansible/playbook.yml

	# Run Ansible playbook
	export ANSIBLE_LOG_PATH=/tmp/ansible.log
	export ANSIBLE_REMOTE_TEMP=/tmp

	# shellcheck disable=SC2086
	ansible-playbook /tmp/ansible-playbook/ansible/playbook.yml \
		--extra-vars '{"stage2":true, "qemu":false}' \
		--extra-vars "git_commit_sha=$GIT_SHA" \
		--extra-vars "psql_version=psql_$POSTGRES_MAJOR_VERSION" \
		--extra-vars "postgresql_version=postgresql_$POSTGRES_MAJOR_VERSION" \
		--extra-vars "nix_secret_key=$NIX_SECRET_KEY" \
		--extra-vars "postgresql_major_version=$POSTGRES_MAJOR_VERSION" \
		$ARGS
}

function cleanup_packages {
	apt-get remove --purge --yes ansible
}

function show_disk_usage {
	echo "disk usage post $1:"
	df /
	df -h /
	du -x -h --max-depth=2 / | sort -rh | head -30
}

# Snapshot disk usage even when a step below fails; errexit would otherwise skip
# the remaining show_disk_usage calls and we'd lose the state we want to debug.
trap 'show_disk_usage EXIT' EXIT

setup_apt
update_and_upgrade_apt
show_disk_usage update_and_upgrade_apt
install_packages
show_disk_usage install_packages
install_nix
show_disk_usage install_nix
execute_stage2_playbook
show_disk_usage ansible
cleanup_packages
update_and_upgrade_apt
cleanup_apt
show_disk_usage update_and_upgrade
