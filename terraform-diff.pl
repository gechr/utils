#!/usr/bin/env perl

use strict;
use warnings;

while (<>) {
  print $_."\e[0m" if /^(\e\[?.*)?([-+~]) / or not /(".*?") => \1/
}
