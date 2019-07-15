#!/bin/bash
##############################################################################################################################################
# Helper functions
##############################################################################################################################################
# Resolves the concrete qualified version for a snaphot m2 artifact
# Parameters
#   $1 -> groupId
#   $2 -> artifactId
#   $3 -> version
function resolve_version(){
    _groupPath=${1//./\/}
    _versionDir="$TEMP_DIR"/"$1"/"$2"
    _metaData=maven-metadata.xml
    if [ ! -d $_versionDir ]
    then
        mkdir -p $_versionDir
    fi
    
    cd $_versionDir || exit
    
    if [ $LOCAL_BUILD == false ]
    then
        if [ ! -f $_metaData ]
        then
            #Download corresponding metadata from snapshot repository
            curl -s "$SNAPSHOT_REPOSITORY"/"$_groupPath"/"$2"/"$3"/$_metaData > $_metaData
        fi
        # Parse timestampt of latest snapshot
        _timestamp=$(xmllint --xpath 'string(/metadata/versioning/snapshot/timestamp)' maven-metadata.xml)
        # Parese buildnummer of latest snapshot
        _buildNummer=$(xmllint --xpath 'string(/metadata/versioning/snapshot/buildNumber)' maven-metadata.xml)
        echo "${3//-SNAPSHOT}"-"${_timestamp}"-"${_buildNummer}"
    else
        echo $3
    fi
}

# Download latest snapshot p2 artifact
# Parameters
#   $1 -> groupdId
#   $2 -> artifactId
#   $3 -> version
#   $4 -> (optional) --sources Flag. if set the corresponding sources should be downloaded as well

function download_artifact() {
    _version=$(resolve_version "$1" "$2" "$3")
    _groupPath=${1//./\/}
    _versionDir="$TEMP_DIR"/"$1"/"$2"
    
    if [ -z "$_version" ]
    then
        echo "ERROR - Could not resolve version info for "$1" "$2" "$3""
        exit 1
    fi
    cd $_versionDir || exit
    _baseURL="$SNAPSHOT_REPOSITORY"/"$_groupPath"/"$2"/"$3"
    _jarfile=${2}-"${_version}".jar
    
    
    download_or_copy  "$_baseURL"/"$_jarfile" #Download jarfile
    
    if [ ! -z $4 ] && [ $4 == "--sources" ]
    then
        download_or_copy  "$_baseURL"/"${_jarfile/.jar/-sources.jar}" #Download sources
    fi
}

# Download or copies (if local build) the file from the given url
#   $1 -> fileUrl
function download_or_copy(){
    if [ $LOCAL_BUILD == true ]
    then
        cp $1 .
    else
        wget $1
    fi
}

# Copy latest snapshot p2 artifact
# Parameters
#   $1 -> groupdId
#   $2 -> artifactId
#   $3 -> version
#   $4 -> destination
#   $5 -> (optional) --sources Flag. if set the corresponding sources should be downloaded as well

function copy_artifact() {
    _version=$(resolve_version "$1" "$2" "$3")
    _versionDir="$TEMP_DIR"/"$1"/"$2"
    _jarfile=${2}-"${_version}".jar
    cd $_versionDir || exit
    if  [ ! -f $_jarfile ]
    then
        download_artifact $1 $2 $3 $5
    fi
    
    cp $_jarfile ${4}/$2-$3.jar
    if [ ! -z $5 ] && [ $5 == "--sources" ]
    then
        cp ${_jarfile/.jar/-sources.jar} ${4}/$2-$3-sources.jar
    fi
}

# Copy source code of latest snapshot p2 artifact
# Parameters
#   $1 -> groupdId
#   $2 -> artifactId
#   $3 -> version
#   $4 -> destination
function copy_sourcecode() {
    _version=$(resolve_version "$1" "$2" "$3")
    _versionDir="$TEMP_DIR"/"$1"/"$2"
    _jarfile=${2}-"${_version}".jar
    cd $_versionDir || exit
    if  [ ! -f $_jarfile ]
    then
        download_artifact $1 $2 $3 --sources
    fi
    _srcDir=${_jarfile/.jar/-sources}
    if  [ ! -d $_srcDir ]
    then
        mkdir $_srcDir
    fi
    cd $_srcDir || exit
    jar -xf ../${_jarfile/.jar/-sources.jar} com/
    cp -r ./ ${4}
}

#Parameters
# Updates the Manifest of an Eclipse plugin (exported packages)
# $1 -> Eclipse plugin name
# $1 -> --rootExport Flag (if set the base package is exported as well)
function update_metadata(){
    PLUGIN_PATH=${1//./\/}
    BASE_DIR="$PLUGIN_DIR"/$1/src/$PLUGIN_PATH
    cd "$BASE_DIR" || exit
    #Find all packages, create and append Export-Package header
    PACKAGE_HEADER=" Export-Package: ";
    
    if [ ! -z $2 ] && [ $2 == "--rootExport" ]
    then
        PACKAGE_HEADER+=${1},\\n
    fi
    
    PACKAGES="$(find . ! -path . -type d)"
    for p in $PACKAGES
    do
        p=${p//.} #remove ./
        p=" "$1${p//\//.} #convert path to qualified package name
        PACKAGE_HEADER+=$p,\\n
    done
    PACKAGE_HEADER=${PACKAGE_HEADER::-3}
    
    echo -e $PACKAGE_HEADER >> $PLUGIN_DIR/$1/META-INF/MANIFEST.MF
}

# Copy a resource of latest snapshot p2 artifact
# Parameters
#   $1 -> groupdId
#   $2 -> artifactId
#   $3 -> version
#   $4 -> resource name
#   $5 -> destination
function copy_resource() {
    _version=$(resolve_version "$1" "$2" "$3")
    _versionDir="$TEMP_DIR"/"$1"/"$2"
    _jarfile=${2}-"${_version}".jar
    
    cd $_versionDir || exit
    if  [ ! -f $_jarfile ]
    then
        download_artifact $1 $2 $3 --sources
    fi
    _srcDir=${_jarfile/.jar/-sources}
    if  [ ! -d $_srcDir ]
    then
        mkdir $_srcDir
    fi
    cd $_srcDir || exit
    jar -xf ../${_jarfile/.jar/-sources.jar} $4
    cp -r ./$4 ${5}
}