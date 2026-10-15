#!/usr/bin/env python3
"""Prepare local machine-translation candidates. This does not approve or enable a language.

Optional development dependencies: transformers<5, torch, sentencepiece, sacremoses.
Download Helsinki-NLP/opus-mt-en-ROMANCE and opus-mt-en-gem separately, then pass
--model-root. App messages remain local. Generated candidates require language review.
"""
import argparse
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LANGUAGES = {'es-419': ('ROMANCE', 'es_MX'), 'de': ('gem', 'deu'),
             'fr': ('ROMANCE', 'fr'), 'pt-BR': ('ROMANCE', 'pt_BR'),
             'it': ('ROMANCE', 'it'), 'nl': ('gem', 'nld'), 'nb': ('gem', 'nob')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-root', required=True, type=Path)
    parser.add_argument('--languages', nargs='+', choices=list(LANGUAGES), default=list(LANGUAGES))
    args = parser.parse_args()
    os.environ['HF_HUB_OFFLINE'] = '1'
    os.environ['TOKENIZERS_PARALLELISM'] = 'false'
    import torch
    from transformers import MarianMTModel, MarianTokenizer
    torch.set_num_threads(2)
    catalogue = json.loads((ROOT / 'Documentation/LocalisationCatalogue.json').read_text())
    keys = sorted(k for k, v in catalogue.items() if v['kind'] == 'text')
    models = {}
    for language in args.languages:
        family, code = LANGUAGES[language]
        if family not in models:
            path = args.model_root / ('opus-mt-en-' + family)
            models[family] = (MarianTokenizer.from_pretrained(path, local_files_only=True),
                              MarianMTModel.from_pretrained(path, local_files_only=True).eval())
        tokenizer, model = models[family]
        path = ROOT / 'Tools/Localisation/drafts' / (language + '.json')
        translations = json.loads(path.read_text())
        translations = {k: v for k, v in translations.items() if k in keys}
        output = ROOT / '.build/localisation-tools/candidates' / (language + '.json')
        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists():
            translations.update({k: v for k, v in json.loads(output.read_text()).items() if k in keys})
        missing = [k for k in keys if k not in translations]
        lines = sorted({line.strip() for k in missing for line in k.splitlines()
                        if line.strip() and any(c.isalpha() for c in line)})
        translated = {}
        for offset in range(0, len(lines), 24):
            batch = lines[offset:offset + 24]
            tokens = tokenizer(['>>' + code + '<< ' + line for line in batch],
                               padding=True, return_tensors='pt', truncation=False)
            with torch.inference_mode():
                outputs = model.generate(**tokens, max_new_tokens=384, num_beams=3)
            for source, value in zip(batch, tokenizer.batch_decode(outputs, skip_special_tokens=True)):
                translated[source] = re.sub(r'\{\s*(\d+)\s*\}', r'{\1}', value)
            if offset % 240 == 0:
                print(language, offset, '/', len(lines), flush=True)
        for key in missing:
            result = []
            for line in key.splitlines(keepends=True):
                text = line.strip()
                if text not in translated:
                    result.append(line)
                    continue
                prefix = line[:len(line)-len(line.lstrip())]
                suffix = line[len(line.rstrip()):]
                value = translated[text]
                if text.isupper():
                    value = value.upper()
                result.append(prefix + value + suffix)
            translations[key] = ''.join(result)
        output.write_text(json.dumps(translations, ensure_ascii=False, sort_keys=True, indent=2) + '\n')
        invalid = [k for k,v in translations.items()
                   if set(re.findall(r'\{\d+\}',k)) != set(re.findall(r'\{\d+\}',v))]
        print(language, 'candidate keys', len(translations), 'invalid placeholders', len(invalid), flush=True)
        (output.with_suffix('.issues.json')).write_text(json.dumps(invalid, ensure_ascii=False, indent=2)+'\n')


if __name__ == '__main__':
    main()
