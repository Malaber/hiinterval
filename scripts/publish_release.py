#!/usr/bin/env python3
"""Publish immutable versioned releases from a successful main CI commit."""
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request


def metadata(version, pull):
    body = pull.get('body') or ''
    title = re.search(r'^Release title:[ \t]*(\S[^\r\n]*)$', body, re.M | re.I)
    notes = re.search(r'^## Release notes[ \t]*\r?\n(.*?)(?=^## |\Z)', body, re.M | re.S | re.I)
    description = re.sub(r'<!--.*?-->', '', notes.group(1), flags=re.S).strip() if notes else ''
    return f"v{version}: {title.group(1).strip() if title else pull['title']}", description


def version_from_project(text):
    found = re.findall(r'^\s*MARKETING_VERSION:\s*[\"\']?(\d+\.\d+\.\d+)[\"\']?\s*$', text, re.M)
    if len(found) != 1:
        raise ValueError('Expected one SemVer MARKETING_VERSION in project.yml')
    return found[0]


def api(path, payload=None, missing_ok=False):
    request = urllib.request.Request('https://api.github.com/' + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                 'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if missing_ok and error.code == 404:
            return None
        raise


def main():
    repo, sha = os.environ['GITHUB_REPOSITORY'], os.environ['RELEASE_SHA']
    if not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('Expected full source SHA')
    version = version_from_project(Path('ios/HiIntervalIOS/project.yml').read_text())
    tag = 'v' + version
    prefix = f'repos/{repo}'
    existing = api(f'{prefix}/releases/tags/{tag}', missing_ok=True)
    # A later docs/CI merge must never rewrite an already published version.
    if existing and not existing['draft']:
        print(f'{tag} already published; leaving release immutable.')
        return
    pulls = api(f'{prefix}/commits/{sha}/pulls')
    pulls = [p for p in pulls if p.get('merged_at') and p['base']['ref'] == 'main'
             and p['base']['repo']['full_name'] == repo and p['merge_commit_sha'] == sha]
    if len(pulls) != 1:
        print('No unique merged main PR for this commit; no release created.')
        return
    ref = api(f'{prefix}/git/ref/tags/{tag}', missing_ok=True)
    if ref:
        obj = ref['object']
        while obj['type'] == 'tag':
            obj = api(f"{prefix}/git/tags/{obj['sha']}")['object']
        if obj['sha'] != sha:
            raise ValueError('Existing tag targets different source; refusing to move it')
    if existing and existing['target_commitish'] != sha:
        raise ValueError('Existing draft targets different source')
    title, notes = metadata(version, pulls[0])
    if not notes:
        notes = api(f'{prefix}/releases/generate-notes',
                    {'tag_name': tag, 'target_commitish': sha})['body']
    archive = Path(f'hiinterval-app-store-screenshots-{tag}.zip')
    subprocess.run(['python3', 'scripts/package_marketing_screenshots.py',
                    '--input', 'release-screenshots', '--output', str(archive),
                    '--version', version, '--commit', sha], check=True)
    notes += (f'\n\n## App Store screenshots\n\n'
              f'[Download iPhone and iPad PNGs](https://github.com/{repo}/releases/download/{tag}/{archive.name})'
              f'\n\nSource: `{sha}` · PR #{pulls[0]["number"]}\n')
    Path('release-notes.md').write_text(notes)
    if not existing:
        subprocess.run(['gh','release','create',tag,'--repo',repo,'--target',sha,
                        '--draft','--title',title,'--notes-file','release-notes.md'],check=True)
    else:
        subprocess.run(['gh','release','edit',tag,'--repo',repo,'--title',title,
                        '--notes-file','release-notes.md'],check=True)
    subprocess.run(['gh','release','upload',tag,str(archive),'--repo',repo,'--clobber'],check=True)
    subprocess.run(['gh','release','edit',tag,'--repo',repo,'--draft=false'],check=True)


if __name__ == '__main__':
    main()
