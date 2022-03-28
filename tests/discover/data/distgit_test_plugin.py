import os

from ruamel.yaml import YAML

from tmt.utils import DistGitHandler


class TestDistGit(DistGitHandler):
    """ Test handler """
    usage_name = "TESTING"
    server = "http://localhost:9000"

    def url_and_name(self, cwd='.'):
        with open(os.path.join(cwd, 'doit.yml')) as f:
            data = YAML(typ="safe").load(f)
        for d in data:
            x = os.path.join(self.server, d['url']), d['source_name']
            yield x
