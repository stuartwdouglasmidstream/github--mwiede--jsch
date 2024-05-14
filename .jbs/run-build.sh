#!/bin/sh
export MAVEN_HOME=/opt/maven/3.8.8
export TOOL_VERSION=3.8.8
export PROJECT_VERSION=0.2.17
export JAVA_HOME=/lib/jvm/java-21
export ENFORCE_VERSION=

set -- "$@" install -DallowIncompleteProjects -Danimal.sniffer.skip -Dcheckstyle.skip -Dcobertura.skip -Denforcer.skip -Dformatter.skip -Dgpg.skip -Dimpsort.skip -Djapicmp.skip -Dmaven.javadoc.failOnError=false -Dmaven.site.deploy.skip -Dpgpverify.skip -Drat.skip=true -Drevapi.skip -Dsort.skip -Dspotbugs.skip -DskipTests -Prelease org.apache.maven.plugins:maven-deploy-plugin:3.1.1:deploy 

#!/usr/bin/env bash
set -o verbose
set -eu
set -o pipefail
FILE="$JAVA_HOME/lib/security/cacerts"
if [ ! -f "$FILE" ]; then
    FILE="$JAVA_HOME/jre/lib/security/cacerts"
fi

if [ -f /root/project/tls/service-ca.crt/service-ca.crt ]; then
    keytool -import -alias jbs-cache-certificate -keystore "$FILE" -file /root/project/tls/service-ca.crt/service-ca.crt -storepass changeit -noprompt
fi



#!/usr/bin/env bash
set -o verbose
set -eu
set -o pipefail

cp -r -a  /original-content/* /root/project
cd /root/project/workspace

if [ -n "" ]
then
    cd 
fi

if [ ! -z ${JAVA_HOME+x} ]; then
    echo "JAVA_HOME:$JAVA_HOME"
    PATH="${JAVA_HOME}/bin:$PATH"
fi

if [ ! -z ${MAVEN_HOME+x} ]; then
    echo "MAVEN_HOME:$MAVEN_HOME"
    PATH="${MAVEN_HOME}/bin:$PATH"
fi

if [ ! -z ${GRADLE_HOME+x} ]; then
    echo "GRADLE_HOME:$GRADLE_HOME"
    PATH="${GRADLE_HOME}/bin:$PATH"
fi

if [ ! -z ${ANT_HOME+x} ]; then
    echo "ANT_HOME:$ANT_HOME"
    PATH="${ANT_HOME}/bin:$PATH"
fi

if [ ! -z ${SBT_DIST+x} ]; then
    echo "SBT_DIST:$SBT_DIST"
    PATH="${SBT_DIST}/bin:$PATH"
fi
echo "PATH:$PATH"

#fix this when we no longer need to run as root
export HOME=/root

mkdir -p /root/project/logs /root/project/packages /root/project/build-info



#This is replaced when the task is created by the golang code


#!/usr/bin/env bash

if [ ! -z ${JBS_DISABLE_CACHE+x} ]; then
    cat >"/root/software/settings"/settings.xml <<EOF
    <settings>
EOF
else
    cat >"/root/software/settings"/settings.xml <<EOF
    <settings>
      <mirrors>
        <mirror>
          <id>mirror.default</id>
          <url>${CACHE_URL}</url>
          <mirrorOf>*</mirrorOf>
        </mirror>
      </mirrors>
EOF
fi

cat >>"/root/software/settings"/settings.xml <<EOF
  <!-- Off by default, but allows a secondary Maven build to use results of prior (e.g. Gradle) deployment -->
  <profiles>
    <profile>
      <id>gradle</id>
      <activation>
        <property>
          <name>useJBSDeployed</name>
        </property>
      </activation>
      <repositories>
        <repository>
          <id>artifacts</id>
          <url>file:///root/project/artifacts</url>
          <releases>
            <enabled>true</enabled>
            <checksumPolicy>ignore</checksumPolicy>
          </releases>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>artifacts</id>
          <url>file:///root/project/artifacts</url>
          <releases>
            <enabled>true</enabled>
            <checksumPolicy>ignore</checksumPolicy>
          </releases>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
</settings>
EOF

#!/usr/bin/env bash

mkdir -p "${HOME}/.m2/repository"
#copy back the gradle folder for hermetic
cp -r /maven-artifacts/* "$HOME/.m2/repository/" || true

echo "MAVEN_HOME=${MAVEN_HOME}"

if [ ! -d "${MAVEN_HOME}" ]; then
    echo "Maven home directory not found at ${MAVEN_HOME}" >&2
    exit 1
fi

TOOLCHAINS_XML="/root/software/settings"/toolchains.xml

cat >"$TOOLCHAINS_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<toolchains>
EOF

if [ "21" = "7" ]; then
    JAVA_VERSIONS="7:1.7.0 8:1.8.0 11:11"
else
    JAVA_VERSIONS="8:1.8.0 9:11 11:11 17:17 21:21"
fi

for i in $JAVA_VERSIONS; do
    version=$(echo $i | cut -d : -f 1)
    home=$(echo $i | cut -d : -f 2)
    cat >>"$TOOLCHAINS_XML" <<EOF
  <toolchain>
    <type>jdk</type>
    <provides>
      <version>$version</version>
    </provides>
    <configuration>
      <jdkHome>/usr/lib/jvm/java-$home-openjdk</jdkHome>
    </configuration>
  </toolchain>
EOF
done

cat >>"$TOOLCHAINS_XML" <<EOF
</toolchains>
EOF

if [ -n "" ]; then
  echo "Setting version to 0.2.17 to match enforced version"
  mvn -B -e -s "/root/software/settings/settings.xml" -t "/root/software/settings/toolchains.xml" org.codehaus.mojo:versions-maven-plugin:2.8.1:set -DnewVersion="0.2.17" | tee /root/project/logs/enforce-version.log
fi

#if we run out of memory we want the JVM to die with error code 134
export MAVEN_OPTS="-XX:+CrashOnOutOfMemoryError"

echo "Running Maven command with arguments: $@"

if [ ! -d /root/project/source ]; then
  cp -r /root/project/workspace /root/project/source
fi
#we can't use array parameters directly here
#we pass them in as goals
mvn -V -B -e -s "/root/software/settings/settings.xml" -t "/root/software/settings/toolchains.xml" "$@" "-DaltDeploymentRepository=local::file:/root/project/artifacts" | tee /root/project/logs/maven.log

cp -r "${HOME}"/.m2/repository/* /root/project/build-info




