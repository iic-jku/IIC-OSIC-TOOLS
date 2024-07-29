#!/bin/bash

set -e

UBUNTU_VERSION=$(lsb_release -r -s)

# Install Quaigh
_install_quaigh () {
	echo "[INFO] Installing Quaigh."
	cd /tmp
	git clone --filter=blob:none https://github.com/coloquinte/Quaigh.git quaigh
	cd quaigh
	git checkout 1b690ebece60a0181df7af22546f13427914cf82
	cargo build
	make clear
	cd ..
	mv quaigh ${TOOLS}/${FAULT_NAME}/${REPO_COMMIT_SHORT}/quaigh
}
_install_quaigh

# Install nl2bench
_install_nl2bench () {
	echo "Installing nl2bench."
	pip3 install --prefix ${TOOLS}/${FAULT_NAME}/${REPO_COMMIT_SHORT}/ nl2bench
}
_install_nl2bench

# Install Swift
_install_swift () {
	echo "[INFO] Installing Swift."
	cd /tmp
	SWIFT_VERSION=5.9.2
	if [[ $UBUNTU_VERSION == 22.04 ]]; then
		if [ "$(arch)" == "x86_64" ]; then
			echo "[INFO] Platform is x86_64, 22.04"
			wget --no-verbose https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2204/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04.tar.gz
			tar xzf swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04.tar.gz
			mv swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04 /opt/swift
		elif [ "$(arch)" == "aarch64" ]; then
			echo "[INFO] Platform is aarch64, 22.04"
			wget --no-verbose https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2204-aarch64/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04-aarch64.tar.gz
			tar xzf swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04-aarch64.tar.gz
			mv swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04-aarch64 /opt/swift
		else
			echo "[ERROR] Unknown platform"
			exit 1
		fi
	else
		echo "[ERROR] Unknown Ubuntu version"
		exit 1
	fi
}
_install_swift
