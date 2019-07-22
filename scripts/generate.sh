#!/bin/bash
##############################################################################################################################################
# Generates Eclipse plugins based on latest maven snapshots
##############################################################################################################################################
. ./functions.sh
# Parameters
#   $1 -> --local Flag for local generation. This uses the local m2. repository for sourcecode retrieval and does not deploy to bintray
echo "# Setup variables"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
ROOT_DIR=$SCRIPT_DIR/..
PLUGIN_DIR=$ROOT_DIR/plugins
TEMP_DIR=$ROOT_DIR/.temp
MS_VERSION=0.0.1-SNAPSHOT

if [ ! -z $1 ] && [ $1 == "--local" ]
then
    export LOCAL_BUILD=true
    export SNAPSHOT_REPOSITORY=$HOME/.m2/repository
    
else
    export LOCAL_BUILD=false
    export SNAPSHOT_REPOSITORY=https://oss.sonatype.org/content/repositories/snapshots
fi


# echo "# Checkout repository skeleton and created temporary directory"
# cd $ROOT_DIR
# git checkout repository_skeleton
rm -rf $TEMP_DIR
mkdir $TEMP_DIR

if [ $LOCAL_BUILD != true ]
then
    MS_SNAPSHOT_VERSION=$(resolve_version com.eclipsesource.modelserver com.eclipsesource.modelserver.parent $MS_VERSION)
    export BINTRAY_QUALIFIER=${MS_SNAPSHOT_VERSION/"${MS_VERSION/-SNAPSHOT}"-}
fi

echo '# Download & copy Modelesrever snapshot sourcecode to plugin'
copy_sourcecode com.eclipsesource.modelserver com.eclipsesource.modelserver.coffee.model $MS_VERSION $PLUGIN_DIR/com.eclipsesource.modelserver.coffee.model/src
copy_sourcecode com.eclipsesource.modelserver com.eclipsesource.modelserver.client $MS_VERSION $PLUGIN_DIR/com.eclipsesource.modelserver.client/src
copy_sourcecode com.eclipsesource.modelserver com.eclipsesource.modelserver.common $MS_VERSION $PLUGIN_DIR/com.eclipsesource.modelserver.common/src

echo '# Copy coffe ecore resources and adapt gen package path'
copy_resource  com.eclipsesource.modelserver com.eclipsesource.modelserver.coffee.model $MS_VERSION Coffee.ecore $PLUGIN_DIR/com.eclipsesource.modelserver.coffee.model/model
copy_resource  com.eclipsesource.modelserver com.eclipsesource.modelserver.coffee.model $MS_VERSION Coffee.genmodel $PLUGIN_DIR/com.eclipsesource.modelserver.coffee.model/model

sed -i 's=/com.eclipsesource.modelserver.coffee.model/src/main/java=/com.eclipsesource.modelserver.coffee.model/src/=g' $PLUGIN_DIR/com.eclipsesource.modelserver.coffee.model/model/Coffee.genmodel


echo "# Update plugin metadata (export packages)"
update_metadata com.eclipsesource.modelserver.coffee.model
update_metadata com.eclipsesource.modelserver.client --rootExport

echo "# P2 Code genereation successful!"
cd $SCRIPT_DIR/..

echo "# Build p2 repository. (Deploy to bintray if non-local)"
if [ $LOCAL_BUILD == true ]
then
    mvn clean install
else
    mvn clean install -Pdeploy-composite
fi