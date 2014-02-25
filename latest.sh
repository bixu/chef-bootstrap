#!/bin/bash
#
# Wanelo's Bastardized Version of Bixu's Bastardized Version of Cuddletech Bastardized Version of https://www.opscode.com/chef/install.sh
# for SmartOS/SNGL Omnibus Installation
#
# @bixu                     09/27/13
# <benr@cuddletech.com>     08/05/13
#

# This is the current stable release to default to, with Omnibus patch level (e.g. 10.12.0-1)
# Note that the chef template downloads 'x.y.z' not 'x.y.z-r' which should be a duplicate of the latest -r
use_shell=0

prerelease="false"

# Check whether a command exists - returns 0 if it does, 1 if it does not
exists() {
  if command -v $1 >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

# Set the filename for the sh archive
shell_filename() {
  filetype="sh"
  filename="chef-${version}-${platform}-${platform_version}-${machine}.sh"
}

report_bug() {
  echo "Please file a bug report at http://tickets.opscode.com"
  echo "Project: Chef"
  echo "Component: Packages"
  echo "Label: Omnibus"
  echo "Version: $version"
  echo " "
  echo "Please detail your operating system type, version and any other relevant details"
}

# Get command line arguments
while getopts spv: opt
do
  case "$opt" in
    v)  version="$OPTARG";;
    s)  use_shell=1;;
    p)  prerelease="true";;
    \?)   # unknown flag
      echo >&2 \
      "usage: $0 [-s] [-v version]"
      exit 1;;
  esac
done
shift `expr $OPTIND - 1`

machine=$(printf `uname -m`)

if grep SmartOS /etc/release >/dev/null;
then
  platform="smartos"
  machine=$(/usr/bin/uname -p)
  platform_version=$(/usr/bin/uname -r)
fi

if [ "x$platform" = "x" ];
then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

if [ "x$platform_version" = "x" ];
then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

shell_filename

echo "Downloading Chef $version for ${platform}..."

#url="https://www.opscode.com/chef/download?v=${version}&prerelease=${prerelease}&p=${platform}&pv=${platform_version}&m=${machine}"


url="https://us-east.manta.joyent.com/wanelo/public/cache/chef/omnibus/chef-11.6.0_0.smartos.5.11.sh"

tmp_dir=$(mktemp -d -t tmp.XXXXXXXX || echo "/tmp")

if exists wget;
then
  downloader="wget"
  wget -O "$tmp_dir/$filename" "$url" 2>/tmp/stderr
elif exists curl;
then
  downloader="curl"
  curl -L "$url" > "$tmp_dir/$filename"
else
  echo "Cannot find wget or curl - cannot install Chef!"
  exit 5
fi

# Check to see if we got a 404 or an empty file

unable_to_retrieve_package() {
  echo "Unable to retrieve a valid package!"
  report_bug
  echo "URL: $url"
  exit 1
}

if [ "$downloader" = "curl" ]
then
  #do curl stuff
  grep "The specified key does not exist." "$tmp_dir/$filename" 2>&1 >/dev/null
  if [ $? -eq 0 ] || [ ! -s "$tmp_dir/$filename" ]
  then
    unable_to_retrieve_package
  fi
elif [ "$downloader" = "wget" ]
then
  #do wget stuff
  grep "ERROR 404" /tmp/stderr 2>&1 >/dev/null
  if [ $? -eq 0 ] || [ ! -s "$tmp_dir/$filename" ]
  then
    unable_to_retrieve_package
  fi
fi

echo "Installing Chef $version"
case "$filetype" in
  "sh" ) bash -- "$tmp_dir/$filename" 2>/dev/null ;;
esac

echo "Updating Chef"
case "$filetype" in
  "sh" ) /opt/chef/embedded/bin/gem install chef --no-ri --no-rdoc 2>/dev/null ;;
esac

if [ "$tmp_dir" != "/tmp" ];
then
  rm -r "$tmp_dir"
fi

if [ $platform == smartos ]; then
  LINK_TARGET="/opt/local/bin"
  mkdir -p $LINK_TARGET
  for BIN in $(ls /opt/chef/bin); do
    ln -f -s /opt/chef/bin/$BIN $LINK_TARGET/$BIN
  done
fi

if [ $? -ne 0 ];
then
  echo "Installation failed"
  report_bug
  exit 1
fi
