#!/bin/sh
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/local/cuda-9.0/extras/CUPTI/lib64/:/usr/local/cuda-9.0/lib64/:$LD_LIBRARY_PATH

export COMPUTE_DATA_DIR=/data/speech/LibriSpeech
export LM_DIR=/data/speech/LM

export EXPERIMENT=SpeechNet-LS-F64-C8-H2048-B16x8

export LOG_DIR=/ds2/experiments/${EXPERIMENT}
export CHECKPOINT_DIR=${LOG_DIR}/checkpoints
export SUMMARY_DIR=${LOG_DIR}/summary

if [ ! -d "$LOG_DIR" ]; then
  mkdir  ${LOG_DIR}
fi
if [ ! -d "$CHECKPOINT_DIR" ]; then
  mkdir  ${CHECKPOINT_DIR}
fi
if [ ! -d "$SUMMARY_DIR" ]; then
  mkdir  ${SUMMARY_DIR}
fi

cp bin/train_sn_librispeech.sh  ${LOG_DIR}

LOG_FILE=${LOG_DIR}/${EXPERIMENT}_$(date +%Y%m%d_%H%M).txt
echo Logging the experiment to $LOG_FILE

CONFIG="\
  --train_files ${COMPUTE_DATA_DIR}/librivox-train-clean-100.csv,${COMPUTE_DATA_DIR}/librivox-train-clean-360.csv,${COMPUTE_DATA_DIR}/librivox-train-other-500.csv \
  --dev_files ${COMPUTE_DATA_DIR}/librivox-dev-clean.csv \
  --test_files ${COMPUTE_DATA_DIR}/librivox-test-clean.csv \
  --input_type logfbank \
  --num_audio_features 64 \
  --num_pad 10 \
  --augment=True \
  --time_stretch_ratio 0.05 \
  --noise_level_max 60 \
  --num_conv_layers 10 \
  --conv_maxpool_fusion=True \
  --num_rnn_layers 0 \
  --row_conv=True \
  --row_conv_width 8 \
  --n_hidden 2048 \
  --train_batch_size 16 \
  --dev_batch_size  16 \
  --test_batch_size 16 \
  --epoch 100 \
  --early_stop 0 \
  --optimizer momentum \
  --momentum 0.9
  --learning_rate 0.0002 \
  --lr_decay_policy poly \
  --decay_power 2.0 \
  --decay_steps 5000 \
  --decay_rate 0.9 \
  --display_step 100 \
  --validation_step 5 \
  --dropout_keep_prob 0.5 \
  --weight_decay 0.0001 \
  --checkpoint_dir ${CHECKPOINT_DIR} \
  --checkpoint_secs 18000 \
  --summary_dir ${SUMMARY_DIR} \
  --summary_secs 600 \
  --lm_binary_path ${LM_DIR}/mozilla-lm.binary \
  --lm_trie_path ${LM_DIR}/mozilla-lm.trie \
  --beam_width 128 \
  --lm_weight 1.5 \
  --word_count_weight 1.0 \
  --valid_word_count_weight 2.5 \
"

echo VERSION: $(git rev-parse --short HEAD) | tee $LOG_FILE
echo CONFIG: | tee -a $LOG_FILE
echo $CONFIG | tee -a $LOG_FILE

python -u SpeechNet.py $CONFIG \
  --wer_log_pattern "GLOBAL LOG: logwer('${COMPUTE_ID}', '%s', '%s', %f)" \
  --decoder_library_path native_client/libctc_decoder_with_kenlm.so \
  "$@" 2>&1 | tee -a $LOG_FILE
