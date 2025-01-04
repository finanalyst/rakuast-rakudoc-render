FROM alpine:3.20

ENV PATH="/usr/share/perl6/site/bin:$PATH"

ARG rakudo=main

# Leave git installed for zef.
RUN apk add --no-cache gcc git linux-headers make musl-dev perl graphviz
RUN git clone -b $rakudo https://github.com/rakudo/rakudo       \
 && cd rakudo                                                   \
 && CFLAGS=-flto ./Configure.pl                                 \
    --gen-moar                                                  \
    --moar-option=--ar=gcc-ar                                   \
    --prefix=/usr                                               \
 && make install                                                \
 && strip /usr/lib/libmoar.so                                   \
 && cd /                                                        \
 && rm -rf rakudo

ARG getopt=0.4.2
ARG prove6=0.0.17
ARG tap=0.3.14
ARG zef=v0.22.5

RUN git clone -b $zef https://github.com/ugexe/zef        \
 && perl6 -Izef/lib zef/bin/zef --/test install ./zef     \
    $([ -z $getopt ] || echo "Getopt::Long:ver<$getopt>") \
    $([ -z $prove6 ] || echo "App::Prove6:ver<$prove6>" ) \
    $([ -z $tap    ] || echo "TAP:ver<$tap>"            ) \
 && rm -rf zef

# install a SASS compiler
ARG DART_SASS_VERSION=1.82.0
ARG DART_SASS_TAR=dart-sass-${DART_SASS_VERSION}-linux-x64-musl.tar.gz
ARG DART_SASS_URL=https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/${DART_SASS_TAR}
ADD ${DART_SASS_URL} /opt/
RUN cd /opt/ && tar -xzf ${DART_SASS_TAR} && rm ${DART_SASS_TAR}
RUN ln -s /opt/dart-sass/sass /usr/local/bin/sass

# install deps in stage that does not depend on copy
RUN zef install PrettyDump Test::Deeply::Relaxed Test::Output LibCurl URI Digest::SHA1::Native Text::MiscUtils Method::Protected Test::Run "Rainbow:ver<0.3.0+>" File::Directory::Tree Test::META

# Copy in Raku source code and build
RUN mkdir -p /opt/rakuast-rakudoc-render
COPY . /opt/rakuast-rakudoc-render
WORKDIR /opt/rakuast-rakudoc-render

RUN zef install . -/precompile-install -/test
RUN bin/force-compile

# symlink executable to location on PATH
RUN ln -s /opt/rakuast-rakudoc-render/bin/RenderDocs /usr/local/bin/RenderDocs

# remove unneeded dependents
RUN apk del gcc linux-headers make musl-dev perl

# Directory where users will mount their documents
RUN mkdir /doc
# Directory where rendered files go
RUN mkdir /to
# Dir for temporary files
RUN mkdir /working
WORKDIR /working

