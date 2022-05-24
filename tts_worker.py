#import os
#import sys
#import io
import logging
import re
from typing import Dict, Any, Optional

import numpy as np
from marshmallow import Schema, fields, ValidationError
from nauron import Worker, Response
from mrln_et.run import synthesize


import settings

from tts_preprocess_et.convert import convert_sentence

logger = logging.getLogger('tts')

# Tensorflow tries to allocate all memory on a GPU unless explicitly told otherwise.
# Does not affect allocation by Pytorch vocoders.
# TODO TF VRAM limit does not illustrate actual VRAM usage

class TTSWorker(Worker):
    def __init__(self, config_path: str, checkpoint_path: str, vocoder_path: str):
        class TTSSchema(Schema):
            text = fields.Str(required=True)
            speaker = fields.Str()
            speed = fields.Float(missing=1, validate=lambda s: 0.5 <= s <= 2)
            application = fields.Str(allow_none=True, missing=None)

        self.silence = np.zeros(10000, dtype=np.int16)
        self.schema = TTSSchema

        #self.config = Config(config_path=config_path)
        #self.model = self.config.load_model(checkpoint_path=checkpoint_path)
        #self.vocoder = HiFiGANPredictor.from_folder(vocoder_path)

        logger.info("Transformer-TTS initialized.")

    def process_request(self, body: Dict[str, Any], _: Optional[str] = None) -> Response:
        try:
            body = self.schema().load(body)
            logger.info(f"Request received: {{"
                        f"speaker: {body['speaker']}, "
                        f"speed: {body['speed']}}}")
            return Response(content=self._synthesize(body['text'], body['speed']), mimetype='audio/wav')
        except ValidationError as error:
            return Response(content=error.messages, http_status_code=400)
        #except tf.errors.ResourceExhaustedError:
        #    return Response(content="Input contains sentences that are too long.", http_status_code=413)

    def _synthesize(self, text: str, speed: float = 1) -> bytes:
        """Convert text to speech waveform.
        Args:
          text (str) : Input text to be synthesized
          speed (float)
        """

        def clean(sent):
            sent = re.sub(r'[`´’\']', r'', sent)
            sent = re.sub(r'[()]', r', ', sent)
            try:
                sent = convert_sentence(sent)
            except Exception as ex:
                logger.error(str(ex), sent)
            sent = re.sub(r'[()[\]:;−­–…—]', r', ', sent)
            sent = re.sub(r'[«»“„”]', r'"', sent)
            sent = re.sub(r'[*\'\\/-]', r' ', sent)
            sent = re.sub(r'[`´’\']', r'', sent)
            sent = re.sub(r' +([.,!?])', r'\g<1>', sent)
            sent = re.sub(r', ?([.,?!])', r'\g<1>', sent)
            sent = re.sub(r'\.+', r'.', sent)

            sent = re.sub(r' +', r' ', sent)
            sent = re.sub(r'^ | $', r'', sent)
            sent = re.sub(r'^, ?', r'', sent)
            sent = re.sub(r'([^.,!?])$', r'\g<1>.', sent)
            
            sent = sent.lower()
            sent = re.sub(re.compile(r'\s+'), ' ', sent)
            return sent


        # The quotation marks need to be unified, otherwise sentence tokenization won't work
        #text = re.sub(r'[«»“„]', r'"', text)

        wav = synthesize(clean(text))

        return wav


if __name__ == '__main__':
    worker = TTSWorker(**settings.WORKER_PARAMETERS)

    worker.start(connection_parameters=settings.MQ_PARAMETERS,
                 service_name=settings.SERVICE_NAME,
                 routing_key=settings.ROUTES[0],
                 alt_routes=settings.ROUTES[1:])
