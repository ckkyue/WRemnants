HISTMAKER_FILE=$1
COMBINE_OUTDIR=$2

CMSSW_BASE=/home/d/dwalter/CMSSW_10_6_30/src

LABEL=Z
ANALYSIS=ZMassDilepton
WEBDIR=231123_dilepton_biasstudy/ptLow

PSEUDODATA=("uncorr" "dyturboN3LLpCorr" "dyturboN3LLp2dCorr" "matrix_radishCorr" "scetlibNPCorr" "scetlibN4LLCorr")
SETS=("asimov" "data" ${PSEUDODATA[@]})

FITVARS=( "ptll" "ptll-yll" )
for FITVAR in "${FITVARS[@]}"; do
    echo Run fits for: ${FITVAR}

    FITVARSTING=$(echo "$FITVAR" | tr '-' '_')

    COMBINE_ANALYSIS_OUTDIR=${COMBINE_OUTDIR}/${ANALYSIS}_${FITVARSTING}/
    COMBINE_ANALYSIS_PATH=${COMBINE_ANALYSIS_OUTDIR}/${ANALYSIS}.hdf5

    if [ -e $COMBINE_ANALYSIS_PATH ]; then
        echo "The file $COMBINE_ANALYSIS_PATH exists, continue using it."
    else
        echo "The file $COMBINE_ANALYSIS_PATH does not exists, continue using it."
        COMMAND="./scripts/ci/run_with_singularity.sh scripts/ci/setup_and_run_python.sh scripts/combine/setupCombine.py \
        -i $HISTMAKER_FILE --fitvar $FITVAR --axlim 0 27 \
        -o $COMBINE_OUTDIR --hdf5 --realData --pseudoData ${PSEUDODATA[@]}"
        echo Run command: $COMMAND
        eval $COMMAND
    fi

    echo Run over: ${SETS[@]}
    for PSEUDO in "${SETS[@]}"; do

        echo "Perform fit for $PSEUDO"

        # 2) pseudodata fit
        FITRESULT=${COMBINE_ANALYSIS_OUTDIR}/fitresults_123456789_${PSEUDO}.hdf5

        if [ -e $FITRESULT ]; then
            echo "The file $FITRESULT exists, continue using it."
        elif [ $PSEUDO == "data" ]; then
            cmssw-cc7 --command-to-run scripts/ci/setup_and_run_combine.sh $CMSSW_BASE $COMBINE_ANALYSIS_OUTDIR \
                ${ANALYSIS}.hdf5 --postfix $PSEUDO --binByBinStat --doImpacts  --saveHists --computeHistErrors
        elif [ $PSEUDO == "asimov" ]; then
            cmssw-cc7 --command-to-run scripts/ci/setup_and_run_combine.sh $CMSSW_BASE $COMBINE_ANALYSIS_OUTDIR \
                ${ANALYSIS}.hdf5 -t -1 --postfix $PSEUDO --binByBinStat --doImpacts  --saveHists --computeHistErrors
        else 
            cmssw-cc7 --command-to-run scripts/ci/setup_and_run_combine.sh $CMSSW_BASE $COMBINE_ANALYSIS_OUTDIR \
                ${ANALYSIS}.hdf5 -p $PSEUDO --postfix $PSEUDO --binByBinStat --doImpacts  --saveHists --computeHistErrors
        fi

        # 3) prefit and postfit plots
        ./scripts/ci/run_with_singularity.sh scripts/ci/setup_and_run_python.sh scripts/plotting/postfitPlots.py \
            $COMBINE_ANALYSIS_OUTDIR/fitresults_123456789_${PSEUDO}.root -f ${WEBDIR}/$PSEUDO --yscale '1.2' --rrange '0.9' '1.1' --prefit
        ./scripts/ci/run_with_singularity.sh scripts/ci/setup_and_run_python.sh scripts/plotting/postfitPlots.py \
            $COMBINE_ANALYSIS_OUTDIR/fitresults_123456789_${PSEUDO}.root -f ${WEBDIR}/$PSEUDO --yscale '1.2' --rrange '0.99' '1.01'
        if [ "${PSEUDO}" != "asimov" ]; then
            echo "Make impacts for ${PSEUDO}"
            ./scripts/ci/run_with_singularity.sh scripts/ci/setup_and_run_python.sh scripts/combine/pullsAndImpacts.py \
                -r $COMBINE_ANALYSIS_OUTDIR/fitresults_123456789_asimov.hdf5 -f $COMBINE_ANALYSIS_OUTDIR/fitresults_123456789_${PSEUDO}.hdf5 \
                -m ungrouped --sortDescending -s constraint \
                output --outFolder /home/d/dwalter/www/WMassAnalysis/${WEBDIR}/$PSEUDO/ -o impactsWlike_${FITVARSTING}.html --otherExtensions pdf png -n 50 
                # --oneSidedImpacts --grouping max -t utilities/styles/nuisance_translate.json \
        fi
    done

    # # 4) make summary table
    # ./scripts/ci/run_with_singularity.sh scripts/ci/setup_and_run_python.sh scripts/tests/summarytable.py \
    #     $COMBINE_ANALYSIS_OUTDIR/fitresults_123456789_*.root -f ${WEBDIR}
    # pdflatex -output-directory /home/d/dwalter/www/WMassAnalysis/${WEBDIR}/ /home/d/dwalter/www/WMassAnalysis/${WEBDIR}/table_${ANALYSIS}.tex
done

# 4) make big summary table
# ./scripts/ci/run_with_singularity.sh scripts/ci/setup_and_run_python.sh scripts/tests/summarytable.py \
#     ${COMBINE_OUTDIR}/${ANALYSIS}_*/fitresults_123456789_*.root -f ${WEBDIR}

# pdflatex -output-directory /home/d/dwalter/www/WMassAnalysis/${WEBDIR}/ /home/d/dwalter/www/WMassAnalysis/${WEBDIR}/table_${ANALYSIS}.tex
