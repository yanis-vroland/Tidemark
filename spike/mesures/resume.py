"""Résume les mesures : python3 resume.py <dossier mesures>. Lit les champs avant rawOutputs."""
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
pat = re.compile(r'TIDEMARK_RESULT (\{"engine".*?),"rawOutputs"')
print('| Appareil | Config | Modèle | Chargement | Mémoire après chargement | Médiane | P90 | JSON valides | Rappel |')
print('| --- | --- | --- | --- | --- | --- | --- | --- | --- |')
for log in sorted(root.glob('*/*.log')):
    text = log.read_bytes().decode('utf-8', 'replace')
    m = pat.search(text)
    if not m:
        err = re.search(r'TIDEMARK ERREUR[^\n]*', text)
        print(f'| {log.parent.name} | {log.stem} | — | {err.group(0)[:80] if err else "sans résultat"} | | | | | |')
        continue
    d = json.loads(m.group(1) + '}')
    print(f"| {log.parent.name} | {log.stem} | {d['modelFile'][:22]} ({d['modelMb']} Mo) | {d['loadMs']/1000:.1f} s | {d['rssAfterLoadMb']} Mo | {d['medianMs']/1000:.2f} s | {d['p90Ms']/1000:.2f} s | {d['validJson']} | {d['meanRecallOnValid']} |")
