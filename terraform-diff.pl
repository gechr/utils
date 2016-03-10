#!/usr/bin/env perl

use strict;
use warnings;

while (<>) {
  s/\e\[?.*?[\@-~]//g;
  print if /^~/ or not /(".*?") => \1/
}
