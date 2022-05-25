from distutils.core import setup
import setuptools
import sys, os

version = "0.4"

setup(
    name="numpydoc",
    packages=["numpydoc"],
    package_dir={"numpydoc": ""},
    version=version,
    description="Sphinx extension to support docstrings in Numpy format",
    # classifiers from http://pypi.python.org/pypi?%3Aaction=list_classifiers
    classifiers=["Development Status :: 3 - Alpha",
                 "Environment :: Plugins",
                 "License :: OSI Approved :: BSD License",
                 "Topic :: Documentation"],
    keywords="sphinx numpy",
    author="Pauli Virtanen and others",
    author_email="pav@iki.fi",
    url="http://github.com/numpy/numpy/tree/master/doc/sphinxext",
    license="BSD",
    zip_safe=False,
    install_requires=["Sphinx >= 1.0.1"],
    package_data={'numpydoc': 'tests', '': ''},
    entry_points={
        "console_scripts": [
            "autosummary_generate = numpydoc.autosummary_generate:main",
        ],
    },
)
