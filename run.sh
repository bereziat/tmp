#!/bin/bash 
# usage obs1..obs4 dir
[[ $# -ne 5 ]] && { echo "wrong parameters"; exit -1; }

# lectures des 4 obs, écriture de W0, F30, F60 dans $dir et configs
# la config est en dur dans le scripts et paramétré pour les expériences de Vincent

SRC=../Rain_Nowcast/RN_Stationary/src
ThreshIm=0.5 # seuillage pluie
dir=$5

ical $1 | grep -q '0.000000      0.000000      0.000000' && { echo "no signal in $1" ; exit 2; }
ical $2 | grep -q '0.000000      0.000000      0.000000' && { echo "no signal in $2" ; exit 2; }
ical $3 | grep -q '0.000000      0.000000      0.000000' && { echo "no signal in $3" ; exit 2; }
ical $4 | grep -q '0.000000      0.000000      0.000000' && { echo "no signal in $4" ; exit 2; }

mkdir -p $dir/init

if [[ -n $(find $dir -name 'ResMotion_iter*.inr') ]]; then
    echo "Found $dir/ResMotion_iter* ... ME passed "
else
    # MOTION ESTIMATION
    raz >$dir/init/W0.inr $(par $1 -x -y) -r -v 2
    cco >$dir/init/Q0.inr -r $1 
    create >$dir/init/Obs.inr $(par $1 -x -y) -r -z 3
    for z in $1 $2 $3; do
	cco -r $z | inrcat >> $dir/init/Obs.inr
    done

    mh -n $ThreshIm $dir/init/Obs.inr | cco -r | sc -n 25 > $dir/init/Rm1.inr
    mb -n $ThreshIm $dir/init/Obs.inr | cco -r | sc -n 0.04 | ad - $dir/init/Rm1.inr $dir/init/Rm1.inr

    cat >$dir/init/MotionEstimation.cfg <<EOF
[model]
meanQ = 0

[run]
#Run parameters
dx = 1200
dy = 1200
NInterObs = 5
dt = 60
Nx = 128
Ny = 128

[assim]
#Assimilation parameters
Nf = 16
#Parameter of the minimizer
accuracy = 1
maxiter = 500

#Background covariance error
Bq = 0.01

#Regularization parameter
alpha = 1e9
beta = 1e6

K = 1

[read]
InDirectory = $dir/init/
OutDirectory = $dir/
             
Rm1File = <InDirectory>Rm1.inr

#Background
MotionT0File = <InDirectory>W0.inr
QT0File = <InDirectory>Q0.inr

#observation
ObsFile = <InDirectory>Obs.inr

[save]
Save = 20   #!!!!!!!! Do not put to 0 !!!!
OutMotionFile = <OutDirectory>ResMotion
OutQFile = <OutDirectory>ResQ

# /dev/null as name means no output
OutMotionAllFile = /dev/null 
OutQAllFile = /dev/null

CumulFile = <OutDirectory>Cumul.inr

[obs] 
Nobs = 3

obs0 = 5
obs1 = 10
obs2 = 15

EOF


    $SRC/MotionEstimation/Assim $dir/init/MotionEstimation.cfg | tee $dir/ME.log

fi

# FORECAST

extg -z 1 -iz 3 $dir/init/Obs.inr >$dir/init/LastObs.inr
extg -z 1 -iz 3 $dir/ResMotion_iter*.inr >$dir/init/WRes.inr

cat > $dir/init/Forecast.cfg <<EOF
[model]
nu_t=0
MeanQ=0
ItDepPt = 5

[run]
dx = 1200
dy = 1200
dt = 30
N = 5

Nx = 128
Ny = 128
Nt = 121

alpha = 1


[options]
PasSave = 1
SaveObs = yes
SaveStateT0 = no


InDirectory = $dir/init/
OutDirectory = $dir/

[read]
InMotionFile = <InDirectory>WRes.inr
InQFile = <InDirectory>LastObs.inr
InObsFile = <InDirectory>RainPred.inr

[save]
OutUVObsFile = <OutDirectory>MObs.inr
OutObsFile = <OutDirectory>QObs.inr

OutMotionFile = /dev/null #<Directory>M.inr
OutQFile = /dev/null #<Directory>Q.inr

OutMotionT0File = <OutDirectory>MT0.inr
OutQT0File = <OutDirectory>QT0.inr

[IC]
T0=0

[obs]
Nobs = 2

obs0=60
obs1=120

EOF

$SRC/Forecast/Simulation $dir/init/Forecast.cfg | tee $dir/Forecast.log

extg -z 1 -iz 1 $dir/QObs.inr | inr2npy '<' $dir/F30.npy
extg -z 1 -iz 2 $dir/QObs.inr | inr2npy '<' $dir/F60.npy


