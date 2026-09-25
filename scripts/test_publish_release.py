import unittest
from publish_release import metadata, version_from_project


class ReleaseMetadataTests(unittest.TestCase):
    def test_explicit_release_fields_exclude_internal_sections(self):
        title, notes = metadata('0.5.4', {'title':'Internal', 'body':
            '## Release\nRelease title: Better workouts\n\n## Release notes\n'
            '<!-- guidance -->\n- New exercises\n\n## Validation\nInternal logs'})
        self.assertEqual(title, 'v0.5.4: Better workouts')
        self.assertEqual(notes, '- New exercises')

    def test_blank_title_does_not_capture_next_line(self):
        self.assertEqual(metadata('1.2.3', {'title':'Fallback','body':
            'Release title:\n\n## Release notes\n<!-- blank -->\n\n## Validation\nDone'}),
            ('v1.2.3: Fallback', ''))

    def test_missing_body_uses_generated_notes(self):
        self.assertEqual(metadata('1.2.3', {'title':'Title','body':None}), ('v1.2.3: Title',''))

    def test_version_comes_from_project(self):
        self.assertEqual(version_from_project('        MARKETING_VERSION: 0.5.4\n'), '0.5.4')
        for invalid in ['MARKETING_VERSION: latest', 'MARKETING_VERSION: 1.2.3\nMARKETING_VERSION: 1.2.4']:
            with self.assertRaises(ValueError): version_from_project(invalid)

class ReleaseSafetyTests(unittest.TestCase):
    def setUp(self):
        from unittest.mock import patch
        self.environment = patch.dict('os.environ', {
            'GITHUB_REPOSITORY': 'Malaber/hiinterval', 'RELEASE_SHA': 'a' * 40})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def test_published_version_is_immutable(self):
        from unittest.mock import patch
        import publish_release
        with patch.object(publish_release, 'api', return_value={'draft': False}) as api, \
             patch.object(publish_release.subprocess, 'run') as run:
            publish_release.main()
        self.assertEqual(api.call_count, 1)
        run.assert_not_called()

    def test_direct_push_does_not_publish(self):
        from unittest.mock import patch
        import publish_release
        with patch.object(publish_release, 'api', side_effect=[None, []]), \
             patch.object(publish_release.subprocess, 'run') as run:
            publish_release.main()
        run.assert_not_called()

    def test_existing_tag_cannot_be_retargeted(self):
        from unittest.mock import patch
        import publish_release
        pull = {'merged_at': 'today', 'base': {'ref':'main','repo':{'full_name':'Malaber/hiinterval'}},
                'merge_commit_sha': 'a' * 40}
        with patch.object(publish_release, 'api', side_effect=[None, [pull],
                  {'object': {'type':'commit','sha':'b' * 40}}]), \
             patch.object(publish_release.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'refusing to move'):
                publish_release.main()
        run.assert_not_called()

    def test_new_release_is_draft_until_asset_upload_finishes(self):
        from tempfile import TemporaryDirectory
        from unittest.mock import patch
        import os
        from pathlib import Path
        import publish_release
        pull = {'title':'Title', 'body':'## Release notes\nCustomer notes', 'number':42,
                'merged_at':'today', 'base':{'ref':'main','repo':{'full_name':'Malaber/hiinterval'}},
                'merge_commit_sha':'a'*40}
        original = os.getcwd()
        with TemporaryDirectory() as directory:
            os.chdir(directory)
            try:
                Path('ios/HiIntervalIOS').mkdir(parents=True)
                Path('ios/HiIntervalIOS/project.yml').write_text('MARKETING_VERSION: 1.2.3\n')
                with patch.object(publish_release, 'api', side_effect=[None,[pull],None]), \
                     patch.object(publish_release.subprocess, 'run') as run:
                    publish_release.main()
                commands = [call.args[0] for call in run.call_args_list]
                self.assertIn('--draft', commands[1])
                self.assertEqual(commands[2][1:3], ['release','upload'])
                self.assertIn('--draft=false', commands[3])
                self.assertIn('Customer notes', Path('release-notes.md').read_text())
            finally:
                os.chdir(original)
