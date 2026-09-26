#!/bin/bash
# EPN, Mon Dec 14 16:55:10 2020
# install.sh
# A shell script for downloading and installing Ribovore and its dependencies.
# 
# usage: 
# install.sh <"linux" or "macosx-intel" or "macosx-silicon">
#
# for example:
# install.sh linux
#
# The following line will make the script fail if any commands fail
set -e 

RIBOINSTALLDIR=$PWD

# versions
VERSION="1.0.5"
# blast+
BVERSION="2.14.1"
# infernal
IVERSION="1.1.5"
IESLCLUSTERVERSION="1.1.2"
# dependency git tag
RVERSION="ribovore-$VERSION"

# set defaults
INPUTSYSTEM="?"
RIBOTYPERONLY="?"
DOKEEP="no"

########################
# Validate correct usage
########################
# make sure correct number of cmdline arguments were used, exit if not
if [ "$#" -ne 1 ]; then
    if [ "$#" -ne 2 ]; then
        echo "Usage:   $0 <os>"
        echo " or "
        echo "Usage:   $0 <os> keep"
        echo ""
        echo "valid options for <os> are:"
        echo "  \"linux\":             full install for linux"
        echo "  \"macosx-intel\":      full install for macosx-intel"
        echo "  \"macosx-silicon\":    full install for macosx-silicon"
        echo "  \"rt-linux\":          ribotyper only for linux"
        echo "  \"rt-macosx-intel\":   ribotyper only for macosx-intel"
        echo "  \"rt-macosx-silicon\": ribotyper only for macosx-silicon"
        echo ""
        echo "use \"keep\" as 2nd argument to keep nonessential files"
        echo "which are normally removed"
        exit 1
    fi
fi

# make sure 1st argument is valid
if [ "$1" = "linux" ]; then
    INPUTSYSTEM="linux";
    RIBOTYPERONLY="no"
fi
if [ "$1" = "macosx-intel" ]; then
    INPUTSYSTEM="macosx-intel";
    RIBOTYPERONLY="no"
fi
if [ "$1" = "macosx-silicon" ]; then
    INPUTSYSTEM="macosx-silicon";
    RIBOTYPERONLY="no"
fi
if [ "$1" = "rt-linux" ]; then
    INPUTSYSTEM="linux";
    RIBOTYPERONLY="yes"
fi
if [ "$1" = "rt-macosx-intel" ]; then
    INPUTSYSTEM="macosx-intel";
    RIBOTYPERONLY="yes"
fi
if [ "$1" = "rt-macosx-silicon" ]; then
    INPUTSYSTEM="macosx-silicon";
    RIBOTYPERONLY="yes"
fi
if [ "$INPUTSYSTEM" = "?" ]; then 
    echo "Usage:   $0 <os>"
    echo " or "
    echo "Usage:   $0 <os> keep"
    echo ""
    echo "valid options for <os> are:"
    echo "  \"linux\":             full install for linux"
    echo "  \"macosx-intel\":      full install for macosx-intel"
    echo "  \"macosx-silicon\":    full install for macosx-silicon"
    echo "  \"rt-linux\":          ribotyper only for linux"
    echo "  \"rt-macosx-intel\":   ribotyper only for macosx-intel"
    echo "  \"rt-macosx-silicon\": ribotyper only for macosx-silicon"
    echo ""
    echo "use \"keep\" as 2nd argument to keep src and other nonessential"
    echo "files which are normally removed"
    exit 1
fi

# make sure 2nd argument (if we have one) is "keep"
if [ "$#" -eq 2 ]; then
    if [ "$2" = "keep" ]; then
        DOKEEP="yes";
    fi
    if [ "$DOKEEP" = "no" ]; then 
        echo "Usage:   $0 <os>"
        echo " or "
        echo "Usage:   $0 <os> keep"
        echo ""
        echo "valid options for <os> are:"
        echo "  \"linux\":             full install for linux"
        echo "  \"macosx-intel\":      full install for macosx-intel"
        echo "  \"macosx-silicon\":    full install for macosx-silicon"
        echo "  \"rt-linux\":          ribotyper only for linux"
        echo "  \"rt-macosx-intel\":   ribotyper only for macosx-intel"
        echo "  \"rt-macosx-silicon\": ribotyper only for macosx-silicon"
        echo ""
        echo "use \"keep\" as 2nd argument to keep src and other nonessential"
        echo "files which are normally removed"
        exit 1
    fi
fi


########################################################
echo "------------------------------------------------"
echo "DOWNLOADING AND BUILDING RIBOVORE $VERSION"
echo "------------------------------------------------"
echo ""
echo "************************************************************"
echo "IMPORTANT: BEFORE YOU WILL BE ABLE TO RUN RIBOVORE SCRIPTS,"
echo "YOU NEED TO FOLLOW THE INSTRUCTIONS OUTPUT AT THE END"
echo "OF THIS SCRIPT TO UPDATE YOUR ENVIRONMENT VARIABLES."
echo "************************************************************"

echo ""
echo "Determining current directory ... "
echo "Set RIBOINSTALLDIR as current directory ($RIBOINSTALLDIR)."

###########################################
# Download section
###########################################
echo "------------------------------------------------"
# ribovore
echo "Downloading ribovore ... "
#curl -k -L -o $RVERSION.zip https://github.com/NLM-DIR/ribovore/archive/$RVERSION.zip; unzip $RVERSION.zip; mv ribovore-$RVERSION ribovore; rm $RVERSION.zip
# for a test build of a release, comment out above curl and uncomment block below
# ----------------------------------------------------------------------------
git clone https://github.com/NLM-DIR/ribovore.git ribovore
cd ribovore
git checkout develop
rm -rf .git
cd ..
# ----------------------------------------------------------------------------
if [ "$RIBOTYPERONLY" = "yes" ]; then
    rm -rf ribovore/taxonomy
fi

# sequip
echo "Downloading sequip ... "
curl -k -L -o sequip-$RVERSION.zip https://github.com/nawrockie/sequip/archive/$RVERSION.zip; unzip sequip-$RVERSION.zip; mv sequip-$RVERSION sequip; rm sequip-$RVERSION.zip
# to checkout a specific branch, comment out above curl and uncomment block below
# ----------------------------------------------------------------------------
#git clone https://github.com/nawrockie/sequip.git sequip
#cd sequip
#git checkout develop
#rm -rf .git
#cd ..
# ----------------------------------------------------------------------------

if [ "$RIBOTYPERONLY" != "yes" ]; then
    # rRNA_sensor
    echo "Downloading rRNA_sensor ... "
    curl -k -L -o rRNA_sensor-$RVERSION.zip https://github.com/aaschaffer/rRNA_sensor/archive/$RVERSION.zip; unzip rRNA_sensor-$RVERSION.zip; mv rRNA_sensor-$RVERSION rRNA_sensor; rm rRNA_sensor-$RVERSION.zip
    # to checkout a specific branch, comment out above curl and uncomment block below
    # ----------------------------------------------------------------------------
    #git clone https://github.com/aaschaffer/rRNA_sensor.git rRNA_sensor
    #cd rRNA_sensor
    #git checkout release-0.14
    #rm -rf .git
    #cd ..
    # ----------------------------------------------------------------------------
fi

# download two infernal binary distributions
# the first is a recent release, we'll use most programs from this release,
# the second is *only* for esl-cluster which is no longer available in current releases
# 
# - to download source distributions and build them instead of binary distributions, see 
#   'infernal block 2' below.

# ----- infernal block 1 start  -----
if [ "$INPUTSYSTEM" = "linux" ]; then
    echo "Downloading Infernal version $IVERSION for Linux"
    curl -k -L -o infernal.tar.gz http://eddylab.org/infernal/infernal-$IVERSION-linux-intel-gcc.tar.gz
    tar xfz infernal.tar.gz
    rm infernal.tar.gz
    mv infernal-$IVERSION-linux-intel-gcc infernal
    if [ "$RIBOTYPERONLY" != "yes" ]; then
        echo "Downloading Infernal version $IESLCLUSTERVERSION for Linux"
        curl -k -L -o infernal2.tar.gz http://eddylab.org/infernal/infernal-$IESLCLUSTERVERSION-linux-intel-gcc.tar.gz
        tar xfz infernal2.tar.gz
        rm infernal2.tar.gz
        mv infernal-$IESLCLUSTERVERSION-linux-intel-gcc/binaries/esl-cluster infernal/binaries/
        rm -rf infernal-$IESLCLUSTERVERSION-linux-intel-gcc
    fi
elif [ "$INPUTSYSTEM" = "macosx-intel" ]; then       
    echo "Downloading Infernal version $IVERSION for Mac/OSX-intel"
    curl -k -L -o infernal.tar.gz http://eddylab.org/infernal/infernal-$IVERSION-macosx-intel.tar.gz
    tar xfz infernal.tar.gz
    rm infernal.tar.gz
    mv infernal-$IVERSION-macosx-intel infernal
    if [ "$RIBOTYPERONLY" != "yes" ]; then
        echo "Downloading Infernal version $IESLCLUSTERVERSION for Mac/OSX"
        curl -k -L -o infernal2.tar.gz http://eddylab.org/infernal/infernal-$IESLCLUSTERVERSION-macosx-intel.tar.gz
        tar xfz infernal2.tar.gz
        rm infernal2.tar.gz
        mv infernal-$IESLCLUSTERVERSION-macosx-intel/binaries/esl-cluster infernal/binaries/
        rm -rf infernal-$IESLCLUSTERVERSION-macosx-intel
    fi
else
    echo "Downloading Infernal version $IVERSION for Mac/OSX-silicon"
    curl -k -L -o infernal.tar.gz http://eddylab.org/infernal/infernal-$IVERSION-macosx-silicon.tar.gz
    # esl-cluster doesn't exist in an infernal release that builds on silicon, but the intel version runs on silicon
    tar xfz infernal.tar.gz
    rm infernal.tar.gz
    mv infernal-$IVERSION-macosx-silicon infernal
    if [ "$RIBOTYPERONLY" != "yes" ]; then
        echo "Downloading Infernal version $IESLCLUSTERVERSION for Mac/OSX"
        curl -k -L -o infernal2.tar.gz http://eddylab.org/infernal/infernal-$IESLCLUSTERVERSION-macosx-intel.tar.gz
        tar xfz infernal2.tar.gz
        rm infernal2.tar.gz
        mv infernal-$IESLCLUSTERVERSION-macosx-intel/binaries/esl-cluster infernal/binaries/
        rm -rf infernal-$IESLCLUSTERVERSION-macosx-intel
    fi
fi
# ----- infernal block 1 end -----

# if you'd rather download the source distros and build them yourself
# (maybe because the binaries aren't working for you for some reason)
# comment out 'infernal block 1' above and 
# uncomment 'infernal block 2' below
#
# ----- infernal block 2 start  -----
#echo "Downloading Infernal version $IVERSION src distribution"
#curl -k -L -o infernal.tar.gz http://eddylab.org/infernal/infernal-$IVERSION.tar.gz
#tar xfz infernal.tar.gz
#rm infernal.tar.gz
#
#echo "Building Infernal ... "
#mv infernal-$IVERSION infernal
#cd infernal
#mkdir binaries
#sh ./configure --bindir=$PWD/binaries --prefix=$PWD
#make
#make install
#(cd easel/miniapps; make install)
#cd ..
#echo "Finished building Infernal version $IESLCLUSTERVERSION"
#
# ----- infernal block 2 end -----
#
################################
    
# download blast binaries
if [ "$INPUTSYSTEM" = "linux" ]; then
    echo "Downloading BLAST version $BVERSION for Linux"
    curl -k -L -o blast.tar.gz https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/$BVERSION/ncbi-blast-$BVERSION+-x64-linux.tar.gz
else 
    echo "Downloading BLAST version $BVERSION for Mac/OSX"
    echo "curl -k -L -o blast.tar.gz https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/$BVERSION/ncbi-blast-$BVERSION+-x64-macosx.tar.gz"
    curl -k -L -o blast.tar.gz https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/$BVERSION/ncbi-blast-$BVERSION+-x64-macosx.tar.gz
fi
tar xfz blast.tar.gz
rm blast.tar.gz
mv ncbi-blast-$BVERSION+ ncbi-blast
echo "------------------------------------------------"

if [ "$RIBOTYPERONLY" != "yes" ]; then
    # if linux, download vecscreen_plus_taxonomy
    if [ "$INPUTSYSTEM" = "linux" ]; then
        curl -k -L -o vecscreen_plus_taxonomy-$RVERSION.zip https://github.com/aaschaffer/vecscreen_plus_taxonomy/archive/$RVERSION.zip; 
        unzip vecscreen_plus_taxonomy-$RVERSION.zip; 
        mv vecscreen_plus_taxonomy-$RVERSION vecscreen_plus_taxonomy
        rm vecscreen_plus_taxonomy-$RVERSION.zip
        (cd vecscreen_plus_taxonomy/scripts; gunzip srcchk.gz; gunzip vecscreen.gz;)
    else 
        echo "Not installing vecscreen_plus_taxonomy (only available for Linux)"
    fi
    echo "------------------------------------------------"
fi

########################################################
# remove nonessential files, unless 'keep' used
if [ "$DOKEEP" = "no" ]; then 
    echo "------------------------------------------------"
    echo "Removing nonessential files"
    # infernal, we only need binaries subdir
    mv infernal/binaries ./binaries
    rm -rf infernal
    mkdir infernal
    mv binaries infernal
    # ncbi-blast, we only need blastdbcmd and blastn
    mv ncbi-blast/bin/blastdbcmd ./
    mv ncbi-blast/bin/blastn ./
    rm -rf ncbi-blast
    mkdir ncbi-blast
    mkdir ncbi-blast/bin
    mv blastdbcmd ncbi-blast/bin
    mv blastn ncbi-blast/bin
    echo "------------------------------------------------"
fi
########################################################

###############################################
# Message about setting environment variables
###############################################
echo "********************************************************"
echo ""
echo "The final step is to update your environment variables."
echo "(See ribovore/README.txt for more information.)"
echo ""
echo "If you are using the bash or zsh shell add the following lines to"
echo "the end of your '.bashrc' or '.zshrc' file in your home directory:"
echo ""
echo "export RIBOINSTALLDIR=\"$RIBOINSTALLDIR\""
echo "export RIBOSCRIPTSDIR=\"\$RIBOINSTALLDIR/ribovore\""
echo "export RIBOINFERNALDIR=\"\$RIBOINSTALLDIR/infernal/binaries\""
echo "export RIBOEASELDIR=\"\$RIBOINSTALLDIR/infernal/binaries\""
echo "export RIBOSEQUIPDIR=\"\$RIBOINSTALLDIR/sequip\""
echo "export RIBOTIMEDIR=\"/usr/bin\""
echo "export RIBOBLASTDIR=\"\$RIBOINSTALLDIR/ncbi-blast/bin\""
if [ "$RIBOTYPERONLY" != "yes" ]; then
    echo "export RRNASENSORDIR=\"\$RIBOINSTALLDIR/rRNA_sensor\""
    if [ "$INPUTSYSTEM" = "linux" ]; then
        echo "export VECPLUSDIR=\"\$RIBOINSTALLDIR/vecscreen_plus_taxonomy\""
        echo "export VECSCREENDIR=\"\$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts\""
        echo "export SRCCHKDIR=\"\$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts\""
        echo "export BLASTDB=\"\$VECPLUSDIR/univec-files\":\"\$RRNASENSORDIR\":\"\$BLASTDB\""
        echo "export PERL5LIB=\"\$RIBOSCRIPTSDIR\":\"\$RIBOSEQUIPDIR\":\"\$VECPLUSDIR\":\"\$PERL5LIB\""
    else
        echo "export BLASTDB=\"\$RRNASENSORDIR\":\"\$BLASTDB\""
        echo "export PERL5LIB=\"\$RIBOSCRIPTSDIR\":\"\$RIBOSEQUIPDIR\":\"\$PERL5LIB\""
    fi
    echo "export PATH=\"\$RIBOSCRIPTSDIR\":\"\$RIBOBLASTDIR\":\"\$RRNASENSORDIR\":\"\$PATH\""
else
    echo "export PERL5LIB=\"\$RIBOSCRIPTSDIR\":\"\$RIBOSEQUIPDIR\":\"\$PERL5LIB\""
    echo "export PATH=\"\$RIBOSCRIPTSDIR\":\"\$PATH\""
fi
echo ""
echo "After adding the export lines to your .bashrc or .zshrc file, source that file"
echo "to update your current environment with the command:"
echo ""
echo "source ~/.bashrc"
echo ""
echo "OR"
echo ""
echo "source ~/.zshrc"
echo ""
echo "---"
echo "If you are using the C shell, add the following"
echo "lines to the end of your '.cshrc' file in your home"
echo "directory:"
echo ""
echo "setenv RIBOINSTALLDIR \"$RIBOINSTALLDIR\""
echo "setenv RIBOSCRIPTSDIR \"\$RIBOINSTALLDIR/ribovore\""
echo "setenv RIBOINFERNALDIR \"\$RIBOINSTALLDIR/infernal/binaries\""
echo "setenv RIBOEASELDIR \"\$RIBOINSTALLDIR/infernal/binaries\""
echo "setenv RIBOSEQUIPDIR \"\$RIBOINSTALLDIR/sequip\""
echo "setenv RIBOTIMEDIR \"/usr/bin\""
if [ "$RIBOTYPERONLY" != "yes" ]; then
    echo "setenv RIBOBLASTDIR \"\$RIBOINSTALLDIR/ncbi-blast/bin\""
    echo "setenv RRNASENSORDIR \"\$RIBOINSTALLDIR/rRNA_sensor\""
    if [ "$INPUTSYSTEM" = "linux" ]; then
        echo "setenv VECPLUSDIR \"\$RIBOINSTALLDIR/vecscreen_plus_taxonomy\""
        echo "setenv VECSCREENDIR \"\$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts\""
        echo "setenv SRCCHKDIR \"\$RIBOINSTALLDIR/vecscreen_plus_taxonomy/scripts\""
        echo "setenv BLASTDB \"\$VECPLUSDIR/univec-files\":\"\$RRNASENSORDIR\":\"\$BLASTDB\""
        echo "setenv PERL5LIB \"\$RIBOSCRIPTSDIR\":\"\$RIBOSEQUIPDIR\":\"\$VECPLUSDIR\":\"\$PERL5LIB\""
    else
        echo "setenv BLASTDB \"\$RRNASENSORDIR\":\"\$BLASTDB\""
        echo "setenv PERL5LIB \"\$RIBOSCRIPTSDIR\":\"\$RIBOSEQUIPDIR\":\"\$PERL5LIB\""
    fi
    echo "setenv PATH \"\$RIBOSCRIPTSDIR\":\"\$RIBOBLASTDIR\":\"\$RRNASENSORDIR\":\"\$PATH\""
else
    echo "setenv PERL5LIB \"\$RIBOSCRIPTSDIR\":\"\$RIBOSEQUIPDIR\":\"\$PERL5LIB\""
    echo "setenv PATH \"\$RIBOSCRIPTSDIR\":\"\$PATH\""
fi
echo ""
echo "After adding the setenv lines to your .cshrc file, source that file"
echo "to update your current environment with the command:"
echo ""
echo "source ~/.cshrc"
echo ""
echo "(To determine which shell you use, type: 'echo \$SHELL')"
echo ""
echo "********************************************************"
echo ""
