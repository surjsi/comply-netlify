#!/bin/bash

if [ -w "/opt/build/cache" ]; then
  CACHE_FOLDER="/opt/build/cache"
else
  CACHE_FOLDER="$HOME/cache"
fi

## Installing comply ##

go get -v github.com/strongdm/comply

## Installing texlive ##

# space-delimited list of extra latex packages to install
# See https://www.ctan.org/pkg/[latexpackage] to find the texlive bundle
LATEXPACKAGES="mdwtools graphics oberdiek setspace amsmath eurosym upquote fancyvrb polyglossia natbib listings tools booktabs parskip bidi fancyhdr"

# Netlify Xenial images don't have a texlive install, so we need to install it on first build.
# We're putting it in the `/opt/build/cache` folder, which is kept between builds
# The following folder is mentioned in netlify-texlive.profile
TEXLIVEDIR="$CACHE_FOLDER/texlive"
TEXLIVEBINDIR="$TEXLIVEDIR/bin/x86_64-linux"

export PATH="$PATH:$TEXLIVEBINDIR:$GOPATH/bin"

# Installing "dep" to "$GOPATH/bin" if absent
if ! type dep > /dev/null 2>&1 ; then
  curl -s https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
fi

# Let's test that a pdflatex executable is present:
if ! type pdflatex > /dev/null 2>&1 ; then
  echo "Installing TeX Live (pdflatex)"
  wget -q http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
  mkdir -p texlive-installer "$TEXLIVEDIR"
  tar -xf install-tl-unx.tar.gz -C ./texlive-installer --strip 1
  printf '%s\n' "# Profile for TeX Live
selected_scheme scheme-small
TEXDIR $TEXLIVEDIR
TEXMFCONFIG \$TEXMFSYSCONFIG
TEXMFHOME \$TEXMFLOCAL
TEXMFLOCAL $TEXLIVEDIR/texmf-local
TEXMFSYSCONFIG $TEXLIVEDIR/texmf-config
TEXMFSYSVAR $TEXLIVEDIR/texmf-var
TEXMFVAR \$TEXMFSYSVAR
binary_x86_64-linux 1
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0" > ./netlify-texlive.profile
  ./texlive-installer/install-tl --profile ./netlify-texlive.profile
else
  echo "TeX Live already installed, proceeding."
fi

# Installing dependencies. If they're already present, they won't be rebuilt.
for val in $LATEXPACKAGES; do
    tlmgr install "$val" || echo "Couldn't install the following LaTeX package: $val"
done

# Building "comply.yml" by substituting ENV variable set on netlify (e.g. GITHUB_TOKEN)
envsubst < comply.dist.yml > comply.yml

# All dependencies are installed (from the second build, everything will be loaded from the cache)
# Let's build the documents now!
./run-comply.sh
