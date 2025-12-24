- [Summary](#org09a9002)
- [Table of Contents](#org34fbd6a)
- [Installation](#org9fb4562)
- [Usage:](#org780dc59)
  - [Following XDG Standards](#orgc1c2948)
  - [Following Classic UNIX Standards](#org934829f)
  - [Available Config File Styles](#org0831b65)
  - [Hash Keys](#orge4aac69)
  - [Hash Values](#org142f762)
    - [YAML](#org0283e2c)
    - [TOML](#orge30bce4)
    - [JSON](#org265b53f)
    - [INI](#org8cb0126)
  - [Creating a Reader](#org9382341)
  - [Calling the `read` method on a `Reader`](#org7567982)
  - [Parsing Environment and Command Line Strings](#parsing-environment-and-command-line-strings)
- [Development](#orgd7c6084)
- [Contributing](#orgf937a13)
- [License](#orga6d60af)

[![img](https://github.com/ddoherty03/fat_config/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/ddoherty03/fat_config/actions/workflows/main.yml)


<a id="org09a9002"></a>

# Summary

Allowing a user to configure an application to change its behavior at runtime can be seen as constructing a ruby `Hash` that merges settings from a variety of sources in a hierarchical fashion: first from system-wide file settings, merged with user-level file settings, merged with environment variable settings, merged with command-line parameters. Constructing this Hash, while needed by nearly any command-line app, can be a tedious chore, especially when there are standards, such as the XDG standards and Unix tradition, that may or may not be followed.

`FatConfig` eliminates the tedium of reading configuration files and the environment to populate a Hash of configuration settings. You need only define a `FatConfig::Reader` and call its `#read` method to look for, read, translate, and merge any config files into a single Hash that encapsulates all the files in the proper priority. It can be set to read `YAML`, `TOML`, `JSON`, or `INI` config files.


<a id="org34fbd6a"></a>

# Table of Contents     :toc_4:

-   
-   
-   -   
    -   
    -   
    -   
    -   -   
        -   
        -   
        -
    -   
    -   
    -   [Parsing Environment and Command Line Strings](#parsing-environment-and-command-line-strings)
-   
-   
-   


<a id="org9fb4562"></a>

# Installation

Install the gem and add to the application's Gemfile by executing:

```sh
bundle add fat_config
```

If bundler is not being used to manage dependencies, install the gem by executing:

```sh
gem install fat_config
```


<a id="org780dc59"></a>

# Usage:

```ruby
require 'fat_config'

reader = FatConfig::Reader.new('myapp')
config = reader.read
```

```

```

The `reader.read` method will parse the config files (by default assumed to be YAML files), config environment variable, and optional command-line parameters and return the composite config as a Hash.


<a id="orgc1c2948"></a>

## Following XDG Standards

By default, `FatConfig::Reader#read` follows the [XDG Desktop Standards](https://specifications.freedesktop.org/basedir-spec/latest/), reading configuration settings for a hypothetical application called `myapp` from the following locations, from lowest priority to highest:

1.  If the environment variable `MYAPP_SYS_CONFIG` is set to the name of a file, it will look in that file for any system-level config file.
2.  If the environment variable `MYAPP_SYS_CONFIG` is NOT set, it will read any system-level config file from `/etc/xdg/myapp` or, if the `XDG_CONFIG_DIRS` environment variable is set to a list of colon-separated directories, it will look in each of those instead of `/etc/xdg` for config directories called `myapp`. If more than one `XDG_CONFIG_DIRS` is given, they are treated as listed in order of precedence, so the first-listed directory will be given priority over later ones. All such directories will be read, and any config file found will be merged into the resulting Hash, but they will be visited in reverse order so that the earlier-named directories override the earlier ones.
3.  If the environment variable `MYAPP_CONFIG` is set to a file name, it will look in that file any user-level config file.
4.  If the environment variable `MYAPP_CONFIG` is NOT set, it will read any user-level config file from `$HOME/.config/myapp` or, if the `XDG_CONFIG_HOME` environment variable is set to an alternative directory, it will look in `XDG_CONFIG_HOME/.config` for a config directory called 'myapp'. Note that in this case, `XDG_CONFIG_HOME` is intended to contain the name of a single directory, not a list of directories as with the system-level config files.
5.  It will then merge in any options set in the environment variable `MYAPP_OPTIONS`, overriding any conflicting settings gotten from reading the system- and user-level files. It will interpret the String from the environment variable as discussed below in [Parsing Environment and Command Line Strings](#parsing-environment-and-command-line-strings).
6.  Finally, it will merge in any options given in the optional `command_line:` named parameter to the `#read` method. That parameter can either be a `Hash` or a `String`. If it is a `String`, it is interpreted the same way as the environment variable `MYAPP_OPTIONS` as explained below in [Parsing Environment and Command Line Strings](#parsing-environment-and-command-line-strings); if it is a `Hash`, it is used directly and merged into the hash returned from the prior methods.


<a id="org934829f"></a>

## Following Classic UNIX Standards

With the optional `:xdg` keyword parameter to `FatConfig::Reader#read` set to `false`, it will follow "classic" UNIX config file conventions. There is no "standard" here, but there are some conventions, and the closest thing I can find to describe the conventions is this from the [UNIX File Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s08.html#homeReferences) website:

> User specific configuration files for applications are stored in the user's home directory in a file that starts with the '.' character (a "dot file"). If an application needs to create more than one dot file then they should be placed in a subdirectory with a name starting with a '.' character, (a "dot directory"). In this case the configuration files should not start with the '.' character.

`FatConfig`'s implementation of this suggestion are as follows for a hypothetical application called `myapp`:

1.  If the environment variable `MYAPP_SYS_CONFIG` is set to a file name, it will look in that file for any system-level config file.
2.  If the environment variable `MYAPP_SYS_CONFIG` is NOT set, then either
    -   if the file `/etc/my_app` exists and is readable, it is considered the system-wide config file for `my_app`, or
    -   if the file `/etc/my_apprc` exists and is readable, it is considered the system-wide config file for `my_app`, or
    -   if the *directory* `/etc/my_app` exists, the first file named `config`, `config.yml`, `config.yaml` (this assumes the default YAML style, the extensions looked for will be adjusted for other styles) , `myapp.config`, or `myapp.cfg` that is readable will be considered the system-wide config file for `my_app`
3.  If the environment variable `MYAPP_CONFIG` is set to a file name, it will look in that file for any user-level config file.
4.  If the environment variable `MYAPP_CONFIG` is NOT set, then either,
    -   if the file, `~/.my_app` or `~/.my_apprc~` exist and are readable, that file is used as the user-level config file,
    -   otherwise, if the directory `~/.my_app/` exists, the first file in that directory named `config`, `config.yml`, `config.yaml`, `myapp.config`, or `myapp.cfg` that is readable will be considered the user-level config file for `my_app`
5.  It will then merge in any options set in the environment variable `MYAPP_OPTIONS`, overriding any conflicting settings gotten from reading the system- and user-level file. It will interpret the environment setting as explained below in [Parsing Environment and Command Line Strings](#parsing-environment-and-command-line-strings).
6.  Finally, it will merge in any options given in the optional `command_line:` named parameter to the `#read` method. That parameter can either be a `Hash` or a `String`. If it is a `String`, it will interpret the string as explained below in [Parsing Environment and Command Line Strings](#parsing-environment-and-command-line-strings); if it is a `Hash`, it is used directly and merged into the hash returned from the prior methods.


<a id="org0831b65"></a>

## Available Config File Styles

`FatConfig::Reader.new` takes the optional keyword argument, `:style`, to indicate what style to use for config files. It can be one of:

-   **`yaml`:** See [YAML Specs](https://yaml.org/spec/1.2.2/),
-   **`toml`:** See [TOML Specs](https://toml.io/en/),
-   **`json`:** See [JSON Specs](https://datatracker.ietf.org/doc/html/rfc8259), or
-   **`ini`:** See [INI File on Wikipedia](https://en.wikipedia.org/wiki/INI_file)

By default, the style is `yaml`. Note that the style only pertains to the syntax of on-disk configuration files. Configuration can also be set by an environment variable, `MYAPP_OPTIONS` and by a command-line string optionally provided to the `#read` method. Those are simple parsers that parse strings of option settings as explained below. See, [Parsing Environment and Command Line Strings](#parsing-environment-and-command-line-strings).


<a id="orge4aac69"></a>

## Hash Keys

The returned Hash will have symbols as keys, using the names given in the config files, except that they will have any hyphens converted to the underscore. Thus the config setting "page-width: 6.5in" in a config file will result in a Hash entry of `{ page_width: '6.5in' }`.


<a id="org142f762"></a>

## Hash Values

Whether the values of the returned Hash will be 'deserialized' into a Ruby object is controlled by the style of the configuration files. For example, the `:yaml` style deserializes the following types:


<a id="org0283e2c"></a>

### YAML

-   TrueClass (the string 'true' of whatever case)
-   FalseClass (the string 'false' of whatever case)
-   NilClass (when no value given)
-   Integer (when it looks like an whole number)
-   Float (when it looks like an decimal number)
-   String (if not one of the other classes or if enclosed in single- or double-quotes)
-   Array (when sub-elements introduced with '-', each typed by these rules)
-   Hash, (when sub-elements introduced with 'key:', each typed by these rules) and,
-   Date, DateTime, and Time, which FatConfig adds to the foregoing default types deserialized by the default YAML library.


<a id="orge30bce4"></a>

### TOML

-   TrueClass (exactly the string 'true')
-   FalseClass (exactly the string 'false')
-   Integer (when it looks like an whole number or 0x&#x2026; or 0o&#x2026; hex or octal)
-   Float (when it looks like an decimal number)
-   String (only if enclosed in single- or double-quotes)
-   Array (when sub-elements enclosed in [&#x2026;], each typed by these rules)
-   Hash, ([hash-key] followed by sub-elements, each typed by these rules) and,
-   Date and Time, when given in ISO form YYYY-MM-DD or YYYY-MM-DDThh:mm:ss


<a id="org265b53f"></a>

### JSON

-   TrueClass (exactly the string 'true')
-   FalseClass (exactly the string 'false')
-   Integer (when it looks like an decimal whole number, but NO provision hex or octal)
-   Float (when it looks like an decimal number)
-   String (only if enclosed in single- or double-quotes)
-   Array (when sub-elements enclosed in [&#x2026;], each typed by these rules)
-   Hash, (when sub-elements enclosed in {&#x2026;}, each typed by these rules) and,
-   Date and Time, NOT deserialized, returns a parse error


<a id="org8cb0126"></a>

### INI

-   TrueClass (exactly the string 'true')
-   FalseClass (exactly the string 'false')
-   Integer (when it looks like an whole number or 0x&#x2026; or 0o&#x2026; hex or octal)
-   Float (when it looks like an decimal number)
-   String (anything else)
-   Array NOT deserialized, returned as a String
-   Hash, NOT deserialized, returned as a String
-   Date and Time, NOT deserialized, returned as a String


<a id="org9382341"></a>

## Creating a Reader

When creating a `Reader`, the `#new` method takes a mandatory argument that specifies the name of the application for which configuration files are to be sought. It also takes a few optional keyword arguments:

-   `style:` specify a style for the config files other than YAML, the choices are `yaml`, `toml`, `json`, and `ini`. This can be given either as a String or Symbol in upper or lower case.
-   `xdg:` either `true`, to follow the XDG standard for where to find config files, or `false`, to follow classic UNIX conventions.
-   `root_prefix:`, to locate the root of the file system somewhere other than `/`. This is probably only useful in testing `FatConfig`.

```ruby
require 'fat_config'

reader1 = FatConfig.new('labrat')  # Use XDG and YAML
reader2 = FatConfig.new('labrat', style: 'toml')  # Use XDG and TOML
reader3 = FatConfig.new('labrat', style: 'ini', xdg: false)  # Use classic UNIX and INI style
```

```
false
```


<a id="org7567982"></a>

## Calling the `read` method on a `Reader`

Once a `Reader` is created, you can get the completely merged configuration as a Hash by calling `Reader#read`. The `read` method can take several parameter:

-   **`alternative base`:** as the first positional parameter, you can give an alternative base name to use for the config files other than the app\_name given in the `Reader.new` constructor. This is useful for applications that may want to have more than one set of configuration files. If given, this name only affects the base names of the config files, not the directory in which they are to be sought: those always use the app name.
-   **`command_line:`:** if you want a command-line to override config values, you can supply one as either a String or a Hash to the `command_line:` keyword parameter. See below for how a String is parsed.
-   **`verbose:`:** if you set `verbose:` true as a keyword argument, the `read` method will report details of how the configuration was built on `$stderr`.
    
    ```ruby
    require 'fat_config'
    
    reader = FatConfig::Reader.new('labrat')
    reader.read  # YAML configs with basename 'labrat'; XDG conventions
    
    # Now read another config set in directories named 'labrat' but with base
    # names of 'labeldb'.  Overrride any setting named fog_psi with command-line
    # value, and report config build on $stderr.
    reader.read('labeldb', command_line: "--fog-psi=3.41mm", verbose: true)
    
    # Similar with a Hash for the command-line
    cl = { fog_psi: '3.41mm' }
    reader.read('labeldb', command_line: cl, verbose: true)
    ```
    
    ```
    | dymo30327: | (page_width: 25mm page_height: 87mm rows: 1 columns: 1 top_page_margin: 0mm bottom_page_margin: 0mm left_page_margin: 5mm right_page_margin: 5mm top_pad: 1mm bottom_pad: 1mm left_pad: 1mm right_pad: 1mm landscape: true printer: dymo) | duraready1034d: | (label: dymo30327 page_width: 23mm page_height: 88mm) | avery5160: | (page_width: 8.5in page_height: 11in rows: 10 columns: 3 top_page_margin: 13mm bottom_page_margin: 12mm left_page_margin: 5mm right_page_margin: 5mm row_gap: 0mm column_gap: 3mm landscape: false) | avery15660: | (label: avery5160) | avery15700: | (label: avery5160) | avery15960: | (label: avery5160) | avery16460: | (label: avery5160) | avery16790: | (label: avery5160) | avery18160: | (label: avery5160) | avery18260: | (label: avery5160) | avery18660: | (label: avery5160) | avery22837: | (label: avery5160) | avery28660: | (label: avery5160) | avery32660: | (label: avery5160) | avery38260: | (label: avery5160) | avery45160: | (label: avery5160) | avery48160: | (label: avery5160) | avery48260: | (label: avery5160) | avery48360: | (label: avery5160) | avery48460: | (label: avery5160) | avery48860: | (label: avery5160) | avery48960: | (label: avery5160) | avery5136: | (label: avery5160) | avery5260: | (label: avery5160) | avery55160: | (label: avery5160) | avery5520: | (label: avery5160) | avery55360: | (label: avery5160) | avery5620: | (label: avery5160) | avery5630: | (label: avery5160) | avery5660: | (label: avery5160) | avery58160: | (label: avery5160) | avery58660: | (label: avery5160) | avery5960: | (label: avery5160) | avery6240: | (label: avery5160) | avery6521: | (label: avery5160) | avery6525: | (label: avery5160) | avery6526: | (label: avery5160) | avery6585: | (label: avery5160) | avery75160: | (label: avery5160) | avery80509: | (label: avery5160) | avery8160: | (label: avery5160) | avery8215: | (label: avery5160) | avery8250: | (label: avery5160) | avery8460: | (label: avery5160) | avery85560: | (label: avery5160) | avery8620: | (label: avery5160) | avery8660: | (label: avery5160) | avery88560: | (label: avery5160) | avery8860: | (label: avery5160) | avery8920: | (label: avery5160) | avery95520: | (label: avery5160) | avery95915: | (label: avery5160) | presta94200: | (label: avery5160) | avery5163: | (page_width: 8.5in page_height: 11in rows: 5 columns: 2 top_page_margin: 12mm bottom_page_margin: 13mm left_page_margin: 4mm right_page_margin: 4mm row_gap: 0mm column_gap: 5mm landscape: false) | avery15513: | (label: avery5163) | avery15702: | (label: avery5163) | avery16791: | (label: avery5163) | avery18163: | (label: avery5163) | avery18863: | (label: avery5163) | avery38363: | (label: avery5163) | avery38863: | (label: avery5163) | avery48163: | (label: avery5163) | avery48263: | (label: avery5163) | avery48363: | (label: avery5163) | avery48463: | (label: avery5163) | avery48863: | (label: avery5163) | avery5137: | (label: avery5163) | avery5263: | (label: avery5163) | avery55163: | (label: avery5163) | avery5523: | (label: avery5163) | avery55463: | (label: avery5163) | avery58163: | (label: avery5163) | avery5963: | (label: avery5163) | avery6427: | (label: avery5163) | avery6527: | (label: avery5163) | avery6528: | (label: avery5163) | avery8163: | (label: avery5163) | avery8253: | (label: avery5163) | avery8363: | (label: avery5163) | avery8463: | (label: avery5163) | avery85563: | (label: avery5163) | avery8563: | (label: avery5163) | avery8923: | (label: avery5163) | avery95523: | (label: avery5163) | avery95910: | (label: avery5163) | avery95945: | (label: avery5163) | avery5366: | (page_width: 8.5in page_height: 11in rows: 15 columns: 2 top_page_margin: 12mm bottom_page_margin: 13mm left_page_margin: 13.5mm right_page_margin: 13.5mm row_gap: 0mm column_gap: 14.5mm landscape: false) | avery45366: | (label: avery5366) | avery48266: | (label: avery5366) | avery48366: | (label: avery5366) | avery5029: | (label: avery5366) | avery5566: | (label: avery5366) | avery6505: | (label: avery5366) | avery75366: | (label: avery5366) | avery8066: | (label: avery5366) | avery8366: | (label: avery5366) | avery8478: | (label: avery5366) | avery8590: | (label: avery5366) | avery8593: | (label: avery5366) | presta94210: | (label: avery5366) | avery5164: | (page_width: 8.5in page_height: 11in rows: 3 columns: 2 top_page_margin: 12.5mm bottom_page_margin: 13mm left_page_margin: 4mm right_page_margin: 4mm row_gap: 0mm column_gap: 5mm landscape: false) | avery15264: | (label: avery5164) | avery45464: | (label: avery5164) | avery48264: | (label: avery5164) | avery48464: | (label: avery5164) | avery48864: | (label: avery5164) | avery5264: | (label: avery5164) | avery55164: | (label: avery5164) | avery5524: | (label: avery5164) | avery55464: | (label: avery5164) | avery58164: | (label: avery5164) | avery6436: | (label: avery5164) | avery8164: | (label: avery5164) | avery8254: | (label: avery5164) | avery8464: | (label: avery5164) | avery8564: | (label: avery5164) | avery95905: | (label: avery5164) | avery95940: | (label: avery5164) | avery5195: | (page_width: 8.5in page_height: 11in rows: 15 columns: 4 top_page_margin: 14mm bottom_page_margin: 14mm left_page_margin: 7.5mm right_page_margin: 8mm row_gap: 0mm column_gap: 7.7mm landscape: false) | avery15695: | (label: avery5195) | avery18195: | (label: avery5195) | avery18294: | (label: avery5195) | avery18695: | (label: avery5195) | avery38667: | (label: avery5195) | avery42895: | (label: avery5195) | avery48335: | (label: avery5195) | avery5155: | (label: avery5195) | avery6430: | (label: avery5195) | avery6520: | (label: avery5195) | avery6523: | (label: avery5195) | avery6524: | (label: avery5195) | avery8195: | (label: avery5195) | avery88695: | (label: avery5195) | presta94208: | (label: avery5195) | avery5167: | (page_width: 8.5in page_height: 11in rows: 20 columns: 4 top_page_margin: 12mm bottom_page_margin: 13mm left_page_margin: 7.5mm right_page_margin: 8mm row_gap: 0mm column_gap: 7.45mm landscape: false) | avery15667: | (label: avery5167) | avery18167: | (label: avery5167) | avery18667: | (label: avery5167) | avery48267: | (label: avery5167) | avery48467: | (label: avery5167) | avery48867: | (label: avery5167) | avery5267: | (label: avery5167) | avery5667: | (label: avery5167) | avery5967: | (label: avery5167) | avery8167: | (label: avery5167) | avery8667: | (label: avery5167) | avery8867: | (label: avery5167) | avery8927: | (label: avery5167) | avery95667: | (label: avery5167) | presta36445: | (label: avery5167) | presta36446: | (label: avery5167) | presta36447: | (label: avery5167) | presta36448: | (label: avery5167) | presta36449: | (label: avery5167) | presta36504: | (label: avery5167) | presta36505: | (label: avery5167) | presta36506: | (label: avery5167) | presta36507: | (label: avery5167) | presta36508: | (label: avery5167) | presta36544: | (label: avery5167) | presta36545: | (label: avery5167) | presta36546: | (label: avery5167) | presta36547: | (label: avery5167) | presta36548: | (label: avery5167) | presta94203: | (label: avery5167) | avery5162: | (page_width: 8.5in page_height: 11in rows: 7 columns: 2 top_page_margin: 21mm bottom_page_margin: 21.5mm left_page_margin: 3.7mm right_page_margin: 5mm row_gap: 0mm column_gap: 5mm landscape: false) | avery18262: | (label: avery5162) | avery48462: | (label: avery5162) | avery48862: | (label: avery5162) | avery5262: | (label: avery5162) | avery5522: | (label: avery5162) | avery5654: | (label: avery5162) | avery5962: | (label: avery5162) | avery6445: | (label: avery5162) | avery6455: | (label: avery5162) | avery8162: | (label: avery5162) | avery8252: | (label: avery5162) | avery8462: | (label: avery5162) | avery95522: | (label: avery5162) | presta94206: | (label: avery5162) | avery5161: | (page_width: 8.5in page_height: 11in rows: 10 columns: 2 top_page_margin: 12mm bottom_page_margin: 13mm left_page_margin: 4.5mm right_page_margin: 4mm row_gap: 0mm column_gap: 5mm landscape: false) | avery5261: | (label: avery5161) | avery5961: | (label: avery5161) | avery8161: | (label: avery5161) | avery8461: | (label: avery5161) | presta36450: | (label: avery5161) | presta36451: | (label: avery5161) | presta36452: | (label: avery5161) | presta36453: | (label: avery5161) | presta36454: | (label: avery5161) | presta36509: | (label: avery5161) | presta36510: | (label: avery5161) | presta36511: | (label: avery5161) | presta36512: | (label: avery5161) | presta36513: | (label: avery5161) | presta36549: | (label: avery5161) | presta36550: | (label: avery5161) | presta36551: | (label: avery5161) | presta36552: | (label: avery5161) | presta36553: | (label: avery5161) | presta94202: | (label: avery5161) | avery5266: | (page_width: 8.5in page_height: 11in rows: 15 columns: 2 top_page_margin: 12.5mm bottom_page_margin: 13mm left_page_margin: 13mm right_page_margin: 14mm row_gap: 0mm column_gap: 14mm landscape: false) | avery5066: | (label: avery5266) | avery5166: | (label: avery5266) | avery5666: | (label: avery5266) | avery5766: | (label: avery5266) | avery5866: | (label: avery5266) | avery5966: | (label: avery5266) | avery6466: | (label: avery5266) | avery6500: | (label: avery5266) | avery5168: | (page_width: 8.5in page_height: 11in rows: 2 columns: 2 top_page_margin: 13mm bottom_page_margin: 13mm left_page_margin: 13mm right_page_margin: 13mm row_gap: 0mm column_gap: 12.5mm landscape: false) | avery27950: | (label: avery5168) | avery8168: | (label: avery5168) | avery95935: | (label: avery5168) | avery5126: | (page_width: 8.5in page_height: 11in rows: 2 columns: 1 top_page_margin: 1mm bottom_page_margin: 1mm left_page_margin: 1mm right_page_margin: 1mm row_gap: 0mm column_gap: 0mm landscape: false) | avery15516: | (label: avery5126) | avery18126: | (label: avery5126) | avery48126: | (label: avery5126) | avery5138: | (label: avery5126) | avery5526: | (label: avery5126) | avery5912: | (label: avery5126) | avery5917: | (label: avery5126) | avery6440: | (label: avery5126) | avery8126: | (label: avery5126) | avery8426: | (label: avery5126) | avery95526: | (label: avery5126) | avery95900: | (label: avery5126) | avery95930: | (label: avery5126) | avery5815: | (page_width: 8.5in page_height: 11in rows: 4 columns: 2 top_page_margin: 13mm bottom_page_margin: 12mm left_page_margin: 4.5mm right_page_margin: 4mm row_gap: 0mm column_gap: 4mm landscape: false) | avery5816: | (label: avery5815) | avery5817: | (label: avery5815) | avery5821: | (label: avery5815) | avery5165: | (page_width: 8.5in page_height: 11in rows: 1 columns: 1 top_page_margin: 0mm bottom_page_margin: 0mm left_page_margin: 0mm right_page_margin: 0mm row_gap: 0mm column_gap: 0mm landscape: false) | avery15265: | (label: avery5165) | avery15665: | (label: avery5165) | avery18665: | (label: avery5165) | avery48165: | (label: avery5165) | avery5265: | (label: avery5165) | avery5353: | (label: avery5165) | avery64506: | (label: avery5165) | avery8165: | (label: avery5165) | avery8255: | (label: avery5165) | avery8465: | (label: avery5165) | avery8665: | (label: avery5165) | avery95920: | (label: avery5165) | avery18663: | (page_width: 8.5in page_height: 11in rows: 5 columns: 2 top_page_margin: 13mm bottom_page_margin: 12mm left_page_margin: 5mm right_page_margin: 5mm row_gap: 0mm column_gap: 3mm landscape: false) | avery15663: | (label: avery18663) | avery5663: | (label: avery18663) | avery6522: | (label: avery18663) | avery7663: | (label: avery18663) | avery8663: | (label: avery18663) | avery5360: | (page_width: 8.5in page_height: 11in rows: 7 columns: 3 top_page_margin: 5.5mm bottom_page_margin: 7mm left_page_margin: 1mm right_page_margin: 1mm row_gap: 0mm column_gap: 0mm landscape: false) | avery45008: | (label: avery5360) | avery8987: | (page_width: 8.5in page_height: 11in rows: 10 columns: 3 top_page_margin: 15mm bottom_page_margin: 16mm left_page_margin: 10mm right_page_margin: 10mm row_gap: 6.3mm column_gap: 13mm landscape: false) | avery8986: | (label: avery8987) | avery18662: | (page_width: 8.5in page_height: 11in rows: 7 columns: 2 top_page_margin: 20.4mm bottom_page_margin: 21.8mm left_page_margin: 5mm right_page_margin: 5mm row_gap: 0mm column_gap: 3mm landscape: false) | avery15662: | (label: avery18662) | avery5662: | (label: avery18662) | avery8662: | (label: avery18662) | avery88662: | (label: avery18662) | avery95662: | (label: avery18662) | avery11124: | (page_width: 8.5in page_height: 11in rows: 20 columns: 2 top_page_margin: 13mm bottom_page_margin: 13mm left_page_margin: 70mm right_page_margin: 70mm row_gap: 0mm column_gap: 0mm landscape: false) | ff: | (label: dymo30327 font_style: bold delta_y: 4mm) | dividers: | (label: avery11124 delta_y: 0mm copies: 2 printer: bro) | fog_psi: | 3.41mm |
    ```


<a id="parsing-environment-and-command-line-strings"></a>

## Parsing Environment and Command Line Strings

The highest priority configs are those contained in the environment variable or in any `command-line:` key-word parameter given to the `#read` method. In the case of the environment variable, the setting is always a String read from the environment.

The `command_line:` key-word parameter can be set to either a String or a Hash. When a Hash is provided, it is used unaltered as a config hash. When a String is provided (and in the case of the environment variable), the string should be something like this:

```
--hello-thing='hello, world' --gb=goodbye world --doit --the_num=3.14159 --the-date=2024-11-27 --no-bueno --~junk
```

And it is parsed into this Hash:

```ruby
{
 :hello_thing=>"hello, world",
 :gb=>"goodbye",
 :doit=>true,
 :the_num=>"3.14159",
 :the_date=>"2024-11-27",
 :bueno=>false,
 :junk=>false
}
```

```
false
```

Here are the parsing rules:

1.  A config element is either of the following, everything else is ignored:
    1.  an "option," of the form "`--<option-name>=<value>`" or
    
    2.  a "flag" of the form "`--<flag-name>`"

2.  All option values are returned as String's and are not deserialized into Ruby objects,
3.  All flags are returned as a boolean `true` or `false`. If the flag name starts with 'no', 'no-', 'no\_', '!', or '~', it is set to `false` and the option name has the negating prefix stripped; otherwise, it is set to `true`.
4.  These rules apply regardless of style being used for config files.


<a id="orgd7c6084"></a>

# Development

After checking out the repo, run \`bin/setup\` to install dependencies. Then, run \`rake spec\` to run the tests. You can also run \`bin/console\` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run \`bundle exec rake install\`. To release a new version, update the version number in \`version.rb\`, and then run \`bundle exec rake release\`, which will create a git tag for the version, push git commits and the created tag, and push the \`.gem\` file to [rubygems.org](https://rubygems.org).


<a id="orgf937a13"></a>

# Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/ddoherty03/fat_config>.


<a id="orga6d60af"></a>

# License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
