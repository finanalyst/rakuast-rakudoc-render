FROM docker.io/rakuland/raku

# install a SASS compiler
ADD dart-sass-1.81.0-linux-x64.tar.gz /opt/
RUN ln -s /opt/dart-sass/sass /usr/local/bin/sass

# Copy in Raku source code and build
RUN mkdir -p /opt/rakuast-rakudoc-render
COPY . /opt/rakuast-rakudoc-render
WORKDIR /opt/rakuast-rakudoc-render
RUN zef install . -/precompile-install

# symlink executable to location on PATH
RUN ln -s /opt/rakuast-rakudoc-render/bin/RenderDocs /usr/local/bin/RenderDocs

# Make a new WORKDIR where users will mount their code
RUN mkdir /src
WORKDIR /src

