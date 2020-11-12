#!/bin/bash

dir=$1

# nb de tâches à lancer en arrière plan
num_jobs_bg=7  
# nb de threads par taches
num_threads=12

echo Required $((num_jobs_bg*num_threads)), you have $(nproc)

set -a Months
Months=(0 31 30 31 30 31 30 31 31 30 31 30 31) # 2018 n'est pas bissextile

next_file() {
    regexp='^([^-]+)-M([0-9]+)-d([0-9]+)-h([0-9]+)-m([0-9]+)\.npy$'
    if [[ $1 =~ $regexp  ]]; then
	prefix=${BASH_REMATCH[1]}
	M=${BASH_REMATCH[2]} d=${BASH_REMATCH[3]} h=${BASH_REMATCH[4]} m=${BASH_REMATCH[5]}
    else
	echo 'Fatal error'
	exit 1
    fi
    if (( m == 55)) ; then
	m=0
	if (( h == 23)); then
	    h=0
	    if ((d==Months[M])); then
		d=1
		M=$((M+1))
	    else
		d=$((d+1))
	    fi
	else
	    h=$((h+1))
	fi
    else
	m=$((m+5))
    fi
#    echo y2018-M$M-d$d-h$h-m$m.npy > `tty`
    echo $prefix-M$M-d$d-h$h-m$m.npy
}

if false; then
    [[ $(next_file y2018-M1-d1-h0-m0.npy) == y2018-M1-d1-h0-m5.npy ]] || { echo Failed ; exit 1; }
    [[ $(next_file y2018-M1-d1-h0-m55.npy) == y2018-M1-d1-h1-m0.npy ]] || { echo Failed ; exit 1; }
    [[ $(next_file y2018-M1-d1-h23-m55.npy) == y2018-M1-d2-h0-m0.npy ]] || { echo Failed ; exit 1; }
    [[ $(next_file y2018-M1-d31-h23-m55.npy) == y2018-M2-d1-h0-m0.npy ]] || { echo Failed ; exit 1; }
    [[ $(next_file y2018-M2-d30-h23-m55.npy) == y2018-M3-d1-h0-m0.npy ]] || { echo Failed ; exit 1; }
fi # tests unitaires de next_file


onetask() {
    M=$1 d=$2 h=$3 m=$4
    dir=$5

    # Calcul des obs
    obs1=$dir/y2018-$M-$d-$h-$m.npy
    obs2=$(next_file $obs1)
    obs3=$(next_file $obs2)
    obs4=$(next_file $obs3)
    
    outdir="results/$M-$d-$h-$m"
    mkdir -p $outdir
    
    if [[ -e $obs1 && -e $obs2 && -e $obs3 && -e $obs4 ]]; then
	OMP_NUM_THREADS=$num_threads ./run.sh $obs1 $obs2 $obs3 $obs4 $outdir > /dev/null
	if [ $0 == 2 ]; then
	    echo "$outdir: window not processed while one date does not contain signal"  | tee -a results/allrun.log
	else
	    echo "$outdir: processed"
	fi
    else
	echo "$outdir: window not processed while one date missed"  | tee -a results/allrun.log
    fi
    
    # Calcul de la date de forecast
    t30=$obs4
    for z in {1..6}; do
	t30=$(next_file $t30)
    done
    t60=$t30
    for z in {1..6}; do
	t60=$(next_file $t60)
    done
    
    mv $outdir/F30.npy results/$t30
    mv $outdir/F60.npy results/$t60
}
    

if [[ -d $dir ]] ; then
    mkdir -p results/val
    rm -f results/allrun.log

    for M in M{1..12}; do
	for d in d{1..31} ; do
	    for h in h{0..23} ; do
		for m in m{0,5,10,15,20,25,30,35,40,45,50,55}; do
#		    test -f y2018-$M-$d-$h-$m.npy || { echo y2018-$M-$d-$h-$m.npy; }

		    ## boucle d'attente des jobs
		    while (( (( $(jobs -p | wc -l) )) >= num_jobs_bg )) 
		    do 
			sleep 4      # check again after 4 seconds
		    done

		    jobs -x onetask $M $d $h $m $dir &
		done
	    done
	done
    done
fi
wait


