#!/bin/bash

#make sure jq is installed on $SCA_SERVICE_DIR
if [ ! -f $SCA_SERVICE_DIR/jq ];
then
        echo "installing jq"
        wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -O $SCA_SERVICE_DIR/jq
        chmod +x $SCA_SERVICE_DIR/jq
fi

#### STARDOCK HEADER
cat <<EOT > Dockerfile
FROM ubuntu:16.04

MAINTAINER Michael Young <youngmd@iu.edu>

RUN apt-get update && apt-get install -y openssh-server
RUN echo "root:test" | chpasswd

RUN useradd -m docker
RUN usermod -s /bin/bash docker
RUN usermod -aG sudo docker
ENV HOME /home/docker
RUN echo "docker:test" | chpasswd

# start up ssh on port 22
RUN mkdir /var/run/sshd
EXPOSE 22

#### END STARDOCK HEADER
EOT

####

##### PARSE APPS REQUESTED AND ADD TO DOCKERFILE
for appid in `jq -r '.apps[] | .["appid"]' config.json`
do
  case '$appid' in
    iraf)
      cat <<EOT >> Dockerfile
### IRAF BUILD
RUN apt-get install --no-install-recommends --fix-missing -y wget csh
#setup directories for iraf
RUN mkdir /iraf
RUN mkdir /iraf/iraf

#download and extract iraf
RUN wget ftp://iraf.noao.edu/iraf/v216/PCIX/iraf.lnux.x86_64.tar.gz
RUN tar -xzf iraf.lnux.x86_64.tar.gz -C /iraf/iraf

#use csh to install iraf
RUN csh
RUN cd /iraf/iraf && ./install --system
RUN exit

#cleanup iraf install
RUN rm iraf.lnux.x86_64.tar.gz

# add iraf environmental stuff to .bashrc
RUN echo "export IRAFARCH=linux64\nexport IRAF=\iraf\iraf\\n >> /home/docker/.bashrc"

### END IRAF BUILD

EOT
  ;;
  ds9)
    cat <<EOT >> Dockerfile
### DS9 BUILD
RUN apt-get install -y saods9
### END DS9 BUILD
EOT
  ;;
  sextractor)
    cat << EOT >> Dockerfile
### SEXTRACTOR BUILD
RUN apt-get install -y sextractor
### END SEXTRACTOR BUILD
EOT
  ;;
  swarp)
    cat << EOT >> Dockerfile
### SWARP BUILD
RUN apt-get install -y swarp
### END SWARP BUILD
EOT
  ;;
  astropy)
    cat << EOT >> Dockerfile
### ASTROPY BUILD
#based on https://github.com/gammapy/gammapy/blob/master/dev/docker/Dockerfile
RUN apt-get update && apt-get install --fix-missing -y wget git bzip2 gcc

# Install conda
RUN wget --quiet http://repo.continuum.io/miniconda/Miniconda-latest-Linux-x86_64.sh -O miniconda.sh
RUN chmod +x miniconda.sh
RUN ./miniconda.sh -b
ENV PATH /root/miniconda/bin:$PATH
RUN conda update --yes conda

ENV NUMPY_VERSION 1.9
ENV ASTROPY_VERSION development

RUN conda install -y numpy=1.9 scipy

RUN git clone http://github.com/astropy/astropy.git
RUN cd /root/astropy && python setup.py install
### END ASTROPY BUILD
EOT
  ;;
done

### INSERT CUSTOM DOCKER BUILD COMMANDS

###

### STARDOCK FOOTER
cat <<EOT >> Dockerfile
#### END STARDOCK
EOT

UUID=$(cat /proc/sys/kernel/random/uuid)

docker build -t stardock-$UUID .
