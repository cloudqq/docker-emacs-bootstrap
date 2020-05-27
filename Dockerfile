FROM ubuntu:18.04 AS builder

ENV DEBIAN_FRONTEND noninteractive

RUN sed --in-place --regexp-extended "s/archive\.ubuntu/azure\.archive\.ubuntu/g" /etc/apt/sources.list \
  && echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf \
  && apt-get update \
  && apt-get install build-essential git cmake zlib1g-dev \
  pkg-config libglib2.0  libreadline-dev


RUN apt-get install doxygen  python python-gi python3-gi python-xlib \
libboost-dev libboost-filesystem-dev libboost-regex-dev libboost-system-dev libboost-locale-dev libgoogle-glog-dev libgtest-dev 

# Manually install libopencc
RUN git clone https://github.com/BYVoid/OpenCC.git
RUN cd OpenCC && git checkout ver.1.0.5 \
&& make PREFIX=/usr/local -j `nproc` && make PREFIX=/usr/local install 

# Fix libgtest problem during compiling
WORKDIR /usr/src/gtest
RUN cmake CMakeLists.txt
RUN make
#copy or symlink libgtest.a and libgtest_main.a to your /usr/lib folder

# ubuntu 18.04
#/usr/src/googletest/googletest/libgtest_main.a
#/usr/src/googletest/googletest/libgtest.a

# ubuntu 20.04
#/usr/src/googletest/googletest/lib/libgtest_main.a
#/usr/src/googletest/googletest/lib/libgtest.a


#RUN find /usr/src/googletest -name "*.a"

RUN cp /usr/src/googletest/googletest/*.a /usr/lib

RUN apt-get install libc6-dev   libyaml-cpp-dev   libleveldb-dev \
  libmarisa-dev  curl

ENV rime_dir=/usr/local/share/rime
RUN curl -fsSL https://git.io/rime-install | bash -s 
#RUN curl -fsSL https://git.io/rime-install | bash -s -- prelude essay luna-pinyin double-pinyin

WORKDIR /
RUN git clone https://github.com/rime/librime.git
WORKDIR librime/
RUN make PREFIX=/usr/local -j `nproc`
RUN make PREFIX=/usr/local install

WORKDIR /
RUN git clone https://github.com/DogLooksGood/emacs-rime.git
WORKDIR emacs-rime/
COPY patches .
RUN git apply  < 0001-add-emacs-module-header.patch
RUN gcc -fPIC -O2 -Wall -shared lib.c -o librime-emacs.so -I. -lrime
RUN find . && echo $(pwd)







FROM rust:latest as builder-tools


RUN \
  git clone --depth 1 https://github.com/BurntSushi/ripgrep \
  && cd ripgrep \
  && cargo build --release \
  && ./target/release/rg --version \
  && cp ./target/release/rg /usr/local/bin \
  && cd / && git clone --depth 1 https://github.com/lotabout/skim.git \
  && cd skim \
  && cargo build --release \
  && ./target/release/sk --version \
  && cp ./target/release/sk /usr/local/bin





FROM ubuntu:18.04 AS builder-emacs

ENV DEBIAN_FRONTEND noninteractive

RUN sed --in-place --regexp-extended "s/archive\.ubuntu/azure\.archive\.ubuntu/g" /etc/apt/sources.list \
  && echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf \
    && apt-get update && \
    apt-get install -y \
            autoconf \
            automake \
            autotools-dev \
            build-essential \
            curl \
            dpkg-dev \
            git \
            gnupg \
            imagemagick \
            ispell \
            libacl1-dev \
            libasound2-dev \
            libcanberra-gtk3-module \
            liblcms2-dev \
            libdbus-1-dev \
            libgif-dev \
            libgnutls28-dev \
            libgpm-dev \
            libgtk-3-dev \
            libjansson-dev \
            libjpeg-dev \
            liblockfile-dev \
            libm17n-dev \
            libmagick++-6.q16-dev \
            libncurses5-dev \
            libotf-dev \
            libpng-dev \
            librsvg2-dev \
            libselinux1-dev \
            libtiff-dev \
            libxaw7-dev \
            libxml2-dev \
            openssh-client \
            python \
            texinfo \
            xaw3dg-dev \
  zlib1g-dev \
  libwebkit2gtk-4.0 \
  libwebkit2gtk-4.0-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://git.savannah.gnu.org/git/emacs.git /opt/emacs 

RUN cd /opt/emacs && \
    ./autogen.sh && \
    ./configure --with-modules --with-x-widgets && \
    make PREFIX=/usr/local -j `nproc` && \
    make install

ENV PATH="/root/.cask/bin:$PATH"
RUN curl -fsSL https://raw.githubusercontent.com/cask/cask/master/go | python

RUN mkdir -p /root/.emacs.d/elpa/gnupg && \
    chmod 700 /root/.emacs.d/elpa/gnupg && \
    gpg -q --homedir /root/.emacs.d/elpa/gnupg -k | grep 81E42C40 || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --homedir /root/.emacs.d/elpa/gnupg --recv-keys 066DAFCB81E42C40




FROM ubuntu:18.04 as builder-exec

RUN sed --in-place --regexp-extended "s/archive\.ubuntu/azure\.archive\.ubuntu/g" /etc/apt/sources.list \
  && echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf \
  && apt-get update \
  && apt-get install build-essential git 

RUN git clone https://github.com/ncopa/su-exec.git /su-exec \
  && cd /su-exec \
  && make \
  && chmod 770 su-exec





FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

ENV emacs_runtime_depends="libtiff5 libpng16-16 libgif7 libsm6 libasound2 libxpm4 xaw3dg  libxrender1 \
librsvg2-2 libdbus-1-3  libxrandr2 libxinerama1 libxfixes3 libgpm2 libotf0 libm17n-0 liblcms2-2 libjansson4 fonts-wqy-zenhei fonts-wqy-microhei ttf-wqy-microhei ttf-wqy-zenhei"
ENV rime_runtime_depends="libyaml-cpp0.5v5 libleveldb1v5 libmarisa0 libboost-regex1.65.1 libboost-system1.65 libgoogle-glog0v5 libboost-filesystem1.65.1"
ENV utils_depends="sudo curl wget git gnupg tmux"
ENV extra_x2go="openbox obconf  conky nitrogen rxvt-unicode-256color apt-utils vim xterm pulseaudio cups curl openssh-server x11-xserver-utils locales"

# emacs runtime
RUN apt-get update && apt-get -y install ${utils_depends} \
    ${emacs_runtime_depends} \
    ${extra_x2go} \
    ${rime_runtime_depends} \
    && rm -rf /var/lib/apt/lists/*


# install fonts

ENV FONT_HOME="/usr/share/fonts"

RUN mkdir -p "${FONT_HOME}/adobe-fonts/source-code-pro"

RUN (git clone \
  --branch release \
  --depth 1 \
  'https://github.com/adobe-fonts/source-code-pro.git' \
  "$FONT_HOME/adobe-fonts/source-code-pro" && \
  fc-cache -f -v "$FONT_HOME/adobe-fonts/source-code-pro")

#install rime
COPY --from=builder /librime/build/bin/*.yaml /usr/local/share/rime/
COPY --from=builder /librime/build/bin/*.txt /usr/local/share/rime/
COPY --from=builder /librime/build/bin/rime_dict_manager /usr/local/bin/
COPY --from=builder /librime/build/bin/rime_deployer /usr/local/bin/
COPY --from=builder /librime/build/lib/librime.so.1.5.3 /usr/local/lib/rime/
#
RUN cd /usr/local/lib/rime && ln -s librime.so.0.5.3 librime.so.1 && ln -s librime.so.1 librime.so
#
#
COPY --from=builder /usr/local/lib/libopencc.so.1.0.0 /usr/local/lib
RUN cd /usr/lib && ln -s  libopencc.so.1.1.0  libopencc.so.2 && ln -s libopencc.so.2 libopencc.so
COPY --from=builder /usr/local/share/opencc/* /usr/local/share/opencc/
COPY --from=builder /usr/local/bin/opencc* /usr/local/bin/
COPY --from=builder /emacs-rime/librime-emacs.so /usr/local/lib/rime/

#
RUN echo '/usr/local/lib/rime' >> /etc/ld.so.conf.d/rime.conf && ldconfig
#
ENV rime_dir=/usr/local/share/rime
RUN curl -fsSL https://git.io/rime-install | bash -s 
#RUN curl -fsSL https://git.io/rime-install | bash -s -- prelude essay luna-pinyin double-pinyin
#
#

# copy tools to emacs sk, rg
COPY --from=builder-tools /usr/local/bin /usr/local/bin


# copy emacs 

COPY --from=builder-emacs /usr/local/bin /usr/local/bin
COPY --from=builder-emacs /usr/local/share/emacs /usr/local/share/emacs
COPY --from=builder-emacs /usr/local/libexec /usr/local/libexec

# copy su-exec  from builder-exec

COPY --from=builder-exec /su-exec/su-exec /usr/local/sbin
COPY asEnvUserSSD /usr/local/sbin/

# Only for sudoers
RUN chown root /usr/local/sbin/asEnvUserSSD \
  && chmod 700  /usr/local/sbin/asEnvUserSSD

# Startup script
#ADD ./start-sshd.sh /root/start-sshd.sh
#RUN chmod 744 /root/start-sshd.sh

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime


RUN echo 'LC_ALL=zh_CN.UTF-8' > /etc/default/locale \
	&& echo 'LANG=zh_CN.UTF-8' /etc/default/locale \
	&& locale-gen zh_CN.UTF-8

RUN emacs --version


#ADD nxserver.sh /

RUN echo '#!/bin/sh\n\
/etc/NX/nxserver --startup\n\
tail -f /usr/NX/var/log/nxserver.log\n '\
> /nxserver.sh && chmod +x /nxserver.sh

#ENTRYPOINT ["/nxserver.sh"]

ENTRYPOINT ["asEnvUserSSD"]
#CMD ["bash", "-c", "emacs; /bin/bash"]




ENV NOMACHINE_VERSION 6.10
ENV NOMACHINE_PACKAGE_NAME nomachine_6.10.12_1_amd64.deb
ENV NOMACHINE_MD5 930ed68876b69a5a20f3f2b2c0650abc

 

# Installation of ssh is required if you want to connect to NoMachine server using SSH protocol when supported.
# Comment it out if you don't need it or if you use NoMachine free.


RUN curl -fSL "http://download.nomachine.com/download/${NOMACHINE_VERSION}/Linux/${NOMACHINE_PACKAGE_NAME}" -o nomachine.deb \
&& echo "${NOMACHINE_MD5} *nomachine.deb" | md5sum -c - \
&& dpkg -i nomachine.deb && rm -rf /nomachine.deb

