#!/usr/bin/env bash

# Restart RStudio server
sudo systemctl restart rstudio-server

# Create temporary package installation script for R
tmpDir="/tmp/r-cran"
mkdir -p $tmpDir
tmpFile="$tmpDir/packages.R"
sudo cat << END >> "$tmpFile"
# Install additional R Packages
install.packages('tidyverse', version='1.3.2', repos='http://cran.r-project.org/')
install.packages('dplyr', version='1.1.0', repos='http://cran.r-project.org/')
install.packages('tidyr', version='1.3.0', repos='http://cran.r-project.org/')
install.packages('ggplot2', version='3.4.1', repos='http://cran.r-project.org/')
install.packages('data.table', version='1.14.6', repos='http://cran.r-project.org/')
install.packages('kableExtra', version='1.3.4', repos='http://cran.r-project.org/')
install.packages('survival', version='3.5.3', repos='http://cran.r-project.org/')
install.packages('survminer', version='0.4.9', repos='http://cran.r-project.org/')
install.packages('MASS', version='7.3.58.2', repos='http://cran.r-project.org/')
install.packages('quantreg', version='5.94', repos='http://cran.r-project.org/')
install.packages('DescTools', version='0.99.47', repos='http://cran.r-project.org/')
install.packages('rentrez', version='1.2.3', repos='http://cran.r-project.org/')
install.packages('XML', version='3.99.0.13', repos='http://cran.r-project.org/')
install.packages('Matrix', version='1.5.3', repos='http://cran.r-project.org/')
install.packages('irlba', version='2.3.5.1', repos='http://cran.r-project.org/')
install.packages('threejs', version='0.3.3', repos='http://cran.r-project.org/')
install.packages('seqinr', version='4.2.23', repos='http://cran.r-project.org/')
install.packages('urltools', version='1.7.3', repos='http://cran.r-project.org/')
install.packages('bitops', version='1.0.7', repos='http://cran.r-project.org/')
install.packages('maptools', version='1.1.6', repos='http://cran.r-project.org/')
install.packages('randomForest', version='4.7.1.1', repos='http://cran.r-project.org/')
install.packages('RCurl', version='1.98.1.10', repos='http://cran.r-project.org/')
install.packages('arsenal', version='3.6.3', repos='http://cran.r-project.org/')

# Install and load remotes package
install.packages('remotes', version='2.4.2', repos='http://cran.r-project.org/')
library('remotes')

remotes::install_github('YuLab-SMU/ggtree', version='3.7.1.2', dep=TRUE)

# Install repos that need a specific order
remotes::install_github('rstudio/httpuv', version='1.6.9', dep=TRUE)
install.packages('shiny', version='1.7.4', repos='http://cran.r-project.org/') # needs httpuv
install.packages('devtools', version='2.4.5', repos='http://cran.r-project.org/') # needs shiny
install.packages('adegenet', version='2.1.10', repos='http://cran.r-project.org/') # needs devtools
END

# Execute installation script
sudo su - -c "R -e \"source('$tmpFile')\""

# Output R library packages
sudo su - -c "R -r \"installed.packages(lib.loc='/usr/local/lib64/R/library')[,'Version']\""

# Cleanup tmp folder
sudo rm -rf "$tmpDir"
