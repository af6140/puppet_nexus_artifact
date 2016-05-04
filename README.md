# nexus_artifact

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with nexus_artifact](#setup)
    * [What nexus_artifact affects](#what-nexus_artifact-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with nexus_artifact](#beginning-with-nexus_artifact)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

This moudle defines a single puppet custom type/provider for downloading nexus artifact.

It was originally based on https://forge.puppetlabs.com/ceh/nexus to avoid potential namesapce confliction, and was quickly realized it does not work well with changing artifact of same version number, like snapshots. Patching the code is problematic, since if nexus is need to be queried, it is better to be done with ruby code, which we cannot be embedded in puppet module. At the same time, functions are pure ruby code and were executed on puppet master. This custom type allows to download artifact from nexus maven repository including snapshots repoistory, since it compares the checksum of artifacts of the same base version. Maven artifacts in snapshots repository can take the form of artifactid-version-SNAPSHOT-timestamp.suffix, though they are the same base versions, but timestamp varies.

## Module Description

A custom type/provider *ent_nexus_getartifact* is implemented to download artifact from nexus.


## Setup

```puppet
include nexus_artifact
```

### What nexus_artifact affects

* Tt requires a tmp_dir available to store the artifact.  
* It fetches artifact from nexus to local file system.

### Setup Requirements **OPTIONAL**

If requires a posix system with  common os commands like wget, chmod, chown. It also requires pluginsync=true enabled for puppet.

### Beginning with nexus_artifact

See source code at ssh://git@stash.entertainment.com:7999/pm/entertainment-nexus_artifact.git.

## Usage

```puppet
ent_nexus_getartifact{'/tmp/coupon_app-static.tar':
        nexus_url => 'https://nexus.mycompany.com/nexus',
        group => 'webapps',
        artifact => 'app-static',
        version => '1.0.3',
        repo => 'entertainment',
        extension => 'tar',
        owner => 'root',
        filegroup => 'root',
        mode => '0755',
        ensure => 'present',
}
```

## Reference

A custom type and provider are available.

### Type
* ent_nexus_getartifact

### Provider
* nexus_fetch

## Limitations

Only tested on Centos/Redhat, against nexus.

## Development

Since your module is awesome, other users will want to play with it. Let them
know what the ground rules for contributing are.

## Release Notes/Contributors/Etc **Optional**

If you aren't using changelog, put your release notes here (though you should
consider using changelog). You may also add any additional sections you feel are
necessary or important to include here. Please use the `## ` header.
