FROM docker.io/rakuland/raku

# Install make, gcc, etc.
RUN apk add build-base

# install a SASS compiler
ARG DART_SASS_VERSION=1.82.0
ARG DART_SASS_TAR=dart-sass-${DART_SASS_VERSION}-linux-x64-musl.tar.gz
ARG DART_SASS_URL=https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/${DART_SASS_TAR}
ADD ${DART_SASS_URL} /opt/
RUN cd /opt/ && tar -xzf ${DART_SASS_TAR} && rm ${DART_SASS_TAR}
RUN ln -s /opt/dart-sass/sass /usr/local/bin/sass

# Copy in Raku source code and build
RUN mkdir -p /opt/rakuast-rakudoc-render
COPY . /opt/rakuast-rakudoc-render
WORKDIR /opt/rakuast-rakudoc-render
RUN zef install . -/precompile-install

# symlink executable to location on PATH
RUN ln -s /opt/rakuast-rakudoc-render/bin/RenderDocs /usr/local/bin/RenderDocs

# Make a new WORKDIR where users will mount their documents
RUN mkdir /src
WORKDIR /src
# Directory where rendered files go
RUN mkdir /to
WORKDIR /to

