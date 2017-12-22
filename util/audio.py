from __future__ import absolute_import, print_function

import scipy.io.wavfile as wav
import sys

try:
    from deepspeech.utils import audioToInputVector
except ImportError:
    import numpy as np
    from python_speech_features import mfcc
    from six.moves import range

    import librosa

    class DeprecationWarning:
        displayed = False

    def audioToInputVector(audio, fs, numcep, numcontext):
        if DeprecationWarning.displayed is not True:
            DeprecationWarning.displayed = True
            print('------------------------------------------------------------------------', file=sys.stderr)
            print('WARNING: libdeepspeech failed to load, resorting to deprecated code',      file=sys.stderr)
            print('         Refer to README.md for instructions on installing libdeepspeech', file=sys.stderr)
            print('------------------------------------------------------------------------', file=sys.stderr)


        # data augmentation
        audio_float = audio.astype(np.float32)/32768.0

        # pitch (slow)
        '''
        pitch_amount = (np.random.rand() - 0.5)*0.5
        audio_float = librosa.effects.pitch_shift(audio_float, fs, pitch_amount)
        '''
        # noise
        noise_level_db = np.random.randint(low=-90, high=-46)
        audio_float += np.random.randn(len(audio))*10**(noise_level_db/20.0)

        audio = (audio_float*32768.0).astype(np.int16)



        # Get mfcc coefficients
        #features = mfcc(audio, samplerate=fs, numcep=numcep)
        features = mfcc(audio, samplerate=fs, winlen=0.025, winstep=0.01,
             numcep=numcep,
             nfilt= 2*numcep,
             nfft=512,
             lowfreq=0, highfreq=None,
             preemph=0.97,
             ceplifter= 2*numcep,  #22,
             appendEnergy=True)

        # We only keep every second feature (BiRNN stride = 2)
        #features = features[::2]

        # One stride per time step in the input
        num_strides = len(features)

        # Add empty initial and final contexts
        empty_context = np.zeros((numcontext, numcep), dtype=features.dtype)
        features = np.concatenate((empty_context, features, empty_context))

        # Create a view into the array with overlapping strides of size
        # numcontext (past) + 1 (present) + numcontext (future)
        window_size = 2*numcontext+1
        train_inputs = np.lib.stride_tricks.as_strided(
            features,
            (num_strides, window_size, numcep),
            (features.strides[0], features.strides[0], features.strides[1]),
            writeable=False)

        # Flatten the second and third dimensions
        train_inputs = np.reshape(train_inputs, [num_strides, -1])

        # Whiten inputs (TODO: Should we whiten?)
        # Copy the strided array so that we can write to it safely
        train_inputs = np.copy(train_inputs)
        train_inputs = (train_inputs - np.mean(train_inputs))/np.std(train_inputs)

        # Return results
        return train_inputs


def audiofile_to_input_vector(audio_filename, numcep, numcontext):
    r"""
    Given a WAV audio file at ``audio_filename``, calculates ``numcep`` MFCC features
    at every 0.01s time step with a window length of 0.025s. Appends ``numcontext``
    context frames to the left and right of each time step, and returns this data
    in a numpy array.
    """
    # Load wav files
    fs, audio = wav.read(audio_filename)

    return audioToInputVector(audio, fs, numcep, numcontext)
