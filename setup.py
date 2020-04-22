from setuptools import setup

install_requires = [
    "boto3",
    "tabulate",
    "requests"
]

dev_requires = [
    "flake8",
    "autopep8",
    "pytest"
]

setup(
    name="dontspendtoomuch",
    description="A little script for monitoring AWS costs",
    author="Spencer Nelson",
    scripts=["dontspendtoomuch.py"],
    install_requires=install_requires,
    extras_require={"dev": dev_requires,},
)
