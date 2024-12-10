#!/bin/sh

set -e

# determining the image type
if [ -f "/etc/cloud/build.info" ] || [ -d "/var/log/installer" ]; then
    if $(grep --max-count=1 --quiet --no-messages "ubuntu-oci" /etc/cloud/build.info); then
        IMAGE_TYPE="ubuntu-oci"
    elif $(grep --max-count=1 --quiet --no-messages "ubuntu-base" /etc/cloud/build.info); then
        IMAGE_TYPE="ubuntu-base"
    elif $(grep --max-count=1 --quiet --no-messages "build_name: minimal" /etc/cloud/build.info); then
        IMAGE_TYPE="ubuntu-cloud"
    else
        IMAGE_TYPE="ubuntu-server"
    fi
fi

if [ -f /etc/dpkg/dpkg.cfg.d/excludes ] || [ -f /etc/dpkg/dpkg.cfg.d/excludes.dpkg-tmp ]; then
    echo "Re-enabling installation of all documentation in dpkg..."
    if [ -f /etc/dpkg/dpkg.cfg.d/excludes ]; then
        mv /etc/dpkg/dpkg.cfg.d/excludes /etc/dpkg/dpkg.cfg.d/excludes.dpkg-tmp
    fi
    echo "Updating package list and upgrading packages..."
    apt-get update
    # apt-get upgrade asks for confirmation before upgrading packages to let the user stop here
    apt-get upgrade
    echo "Restoring system documentation..."
    echo "Reinstalling packages with files in /usr/share/man/ ..."
    # Reinstallation takes place in two steps because a single dpkg --verified
    # command generates very long parameter list for "xargs dpkg -S" and may go
    # over ARG_MAX. Since many packages have man pages the second download
    # handles a much smaller amount of packages.
    dpkg -S /usr/share/man/ |sed 's|, |\n|g;s|: [^:]*$||' | DEBIAN_FRONTEND=noninteractive xargs --no-run-if-empty apt-get install --reinstall -y
    echo "Reinstalling packages with system documentation in /usr/share/doc/ .."
    # This step processes the packages which still have missing documentation
    dpkg --verify --verify-format rpm | awk '$2 ~ /\/usr\/share\/doc/ {print $2}' | sed 's|/[^/]*$||' | sort | uniq \
         | xargs --no-run-if-empty dpkg -S | sed 's|, |\n|g;s|: [^:]*$||' | uniq | DEBIAN_FRONTEND=noninteractive xargs --no-run-if-empty apt-get install --reinstall -y
    echo "Restoring system translations..."
    # This step processes the packages which still have missing translations
    dpkg --verify --verify-format rpm | awk '$2 ~ /\/usr\/share\/locale/ {print $2}' | sed 's|/[^/]*$||' | sort | uniq \
         | xargs --no-run-if-empty dpkg -S | sed 's|, |\n|g;s|: [^:]*$||' | uniq | DEBIAN_FRONTEND=noninteractive xargs --no-run-if-empty apt-get install --reinstall -y
    if dpkg --verify --verify-format rpm | awk '$2 ~ /\/usr\/share\/doc/ {exit 1}'; then
        echo "Documentation has been restored successfully."
        rm /etc/dpkg/dpkg.cfg.d/excludes.dpkg-tmp
    else
        echo "There are still files missing from /usr/share/doc/:"
        dpkg --verify --verify-format rpm | awk '$2 ~ /\/usr\/share\/doc/ {print " " $2}'
        echo "You may want to try running this script again or you can remove"
        echo "/etc/dpkg/dpkg.cfg.d/excludes.dpkg-tmp and restore the files manually."
    fi
fi

if  [ "$(dpkg-divert --truename /usr/bin/man)" = "/usr/bin/man.REAL" ]; then
    # Remove diverted man binary
    rm -f /usr/bin/man
    dpkg-divert --quiet --remove --rename /usr/bin/man
fi

if [ "$IMAGE_TYPE" != "ubuntu-oci" ] && [ "$IMAGE_TYPE" != "ubuntu-base" ]; then
    # ubuntu-minimal is too much for a docker container (it contains systemd and other things)

    if ! dpkg-query --show --showformat='${db:Status-Status}\n' ubuntu-minimal 2> /dev/null | grep -q '^installed$'; then
        echo "Installing ubuntu-minimal package to provide the familiar Ubuntu minimal system..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-minimal ubuntu-standard
    fi

    if dpkg-query --show --showformat='${db:Status-Status}\n' ubuntu-server 2> /dev/null | grep -q '^installed$' \
       && ! dpkg-query --show --showformat='${db:Status-Status}\n' landscape-common 2> /dev/null | grep -q '^installed$'; then
        echo "Installing ubuntu-server recommends..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y landscape-common
    fi
fi

if [ "$IMAGE_TYPE" = "ubuntu-cloud" ]; then
    # we'd like to transform a cloud minimized image to a cloud base image when unminimize is run.

    # even if ubuntu-server is installed, we should re-install it with --fix-policy --install-recommends
    # to ensure all the Recommends of dependencies of ubuntu-server are installed, which aids in transforming
    # this minimized image to an equivalent base image.
    DEBIAN_FRONTEND=noninteractive apt-get --reinstall --fix-policy --install-recommends install -y ubuntu-server

    if dpkg-query --show --showformat='${db:Status-Status}\n' linux-image-virtual 2> /dev/null | grep -q '^installed$'; then
        echo "Installing linux-virtual for installing the headers which were stripped in a minimized image"
        DEBIAN_FRONTEND=noninteractive apt-get install -y linux-virtual
    fi
fi

# unminimization succeeded, there is no need to mention it in motd
rm -f /etc/update-motd.d/60-unminimize