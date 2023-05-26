#!/bin/bash

# Step 1: Check JDK version
java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [[ "$java_version" < "1.8" ]]; then
    echo "Java version is lower than 1.8. Installing Java 8..."
    sudo apt-get update
    sudo apt-get install openjdk-8-jdk
    echo "Java 8 installed successfully!"
elif [[ "$java_version" > "1.8" ]]; then
    echo "Java version is higher than 1.8. Removing current Java installation..."
    sudo apt-get purge -y openjdk-\*
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    echo "Java removed successfully!"
    echo "Installing Java 8..."
    sudo apt-get update
    sudo apt-get install openjdk-8-jdk
    echo "Java 8 installed successfully!"
else
    echo "Java 8 is already installed!"
fi

# Continue with the rest of the script

# Step 2: Add Hadoop user
sudo addgroup hadoop
sudo adduser --ingroup hadoop hduser
sudo adduser hduser sudo

# Step 3: Install SSH
sudo apt-get update
sudo apt-get install openssh-server

# Step 4: Create and setup SSH certificates
sudo -u hduser ssh-keygen -t rsa -P "" -f /home/hduser/.ssh/id_rsa
cat /home/hduser/.ssh/id_rsa.pub >> /home/hduser/.ssh/authorized_keys
ssh localhost

# Step 5: Extract Hadoop
sudo tar xfz hadoop-2.9.0.tar.gz -C /usr/local
sudo chown -R hduser:hadoop /usr/local/hadoop-2.9.0

# Step 6: Setup configuration files
# ~/.bashrc
cat << EOF >> /home/hduser/.bashrc

# HADOOP VARIABLES START
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/usr/local/hadoop-2.9.0
export PATH=\$PATH:\$HADOOP_HOME/bin
export PATH=\$PATH:\$HADOOP_HOME/sbin
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export HADOOP_OPTS="-Djava.library.path=\$HADOOP_HOME/lib"
# HADOOP VARIABLES END

EOF

source /home/hduser/.bashrc

# /usr/local/hadoop/etc/hadoop/hadoop-env.sh
sudo sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64\nexport HADOOP_CONF_DIR=/usr/local/hadoop-2.9.0/etc/hadoop/:' /usr/local/hadoop-2.9.0/etc/hadoop/hadoop-env.sh

# /usr/local/hadoop/etc/hadoop/core-site.xml
sudo tee /usr/local/hadoop-2.9.0/etc/hadoop/core-site.xml > /dev/null << EOF
<configuration>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://localhost:9000</value>
  </property>
</configuration>
EOF

# /usr/local/hadoop/etc/hadoop/mapred-site.xml
sudo cp /usr/local/hadoop-2.9.0/etc/hadoop/mapred-site.xml.template /usr/local/hadoop-2.9.0/etc/hadoop/mapred-site.xml
sudo tee /usr/local/hadoop-2.9.0/etc/hadoop/mapred-site.xml > /dev/null << EOF
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOF

# /usr/local/hadoop/etc/hadoop/hdfs-site.xml
sudo tee /usr/local/hadoop-2.9.0/etc/hadoop/hdfs-site.xml > /dev/null << EOF
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:/usr/local/hadoop_tmp/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:/usr/local/hadoop_tmp/hdfs/datanode</value>
  </property>
</configuration>
EOF

# /usr/local/hadoop/etc/hadoop/yarn-site.xml
sudo tee /usr/local/hadoop-2.9.0/etc/hadoop/yarn-site.xml > /dev/null << EOF
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
</configuration>
EOF

# Step 7: Format the Hadoop Filesystem
/usr/local/hadoop-2.9.0/bin/hadoop namenode -format

# Step 8: Start Hadoop
/usr/local/hadoop-2.9.0/sbin/start-all.sh

# Step 9: Verify Hadoop Web Interfaces
jps
