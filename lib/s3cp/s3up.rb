# Copyright (C) 2010-2012 Alex Boisvert and Bizo Inc. / All rights reserved.
#
# Licensed to the Apache Software Foundation (ASF) under one or more contributor
# license agreements.  See the NOTICE file  distributed with this work for
# additional information regarding copyright ownership.  The ASF licenses this
# file to you under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License.  You may obtain a copy of
# the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

require 'rubygems'
require 'extensions/kernel' if RUBY_VERSION =~ /1.8/
require 'right_aws'
require 'optparse'
require 'tempfile'

require 's3cp/utils'

# Parse arguments
options = {}
options[:tty] = $stdout.isatty
options[:headers] = []

op = OptionParser.new do |opts|
  opts.banner = "s3up [s3_path]"
  opts.separator ''
  opts.separator 'Uploads data from STDIN to S3.'

  opts.on('--headers \'Header1: Header1Value\',\'Header2: Header2Value\'', Array, "Headers to set on the item in S3." ) do |h|
    options[:headers] = h
  end

  opts.separator "        e.g.,"
  opts.separator "              HTTP headers: \'Content-Type: image/jpg\'"
  opts.separator "               AMZ headers: \'x-amz-acl: public-read\'"
  opts.separator ""

  opts.on_tail("-h", "--help", "Show this message") do
    puts op
    exit
  end
end
op.parse!(ARGV)

unless ARGV.size > 0
  puts op
  exit
end

def headers_array_to_hash(header_array)
  headers = {}
  header_array.each do |header|
    header_parts = header.split(": ", 2)
    if header_parts.size == 2
      headers[header_parts[0].downcase] = header_parts[1]  # RightAWS gem expect lowercase header names :(
    else
      log("Header ignored because of error splitting [#{header}].  Expected colon delimiter; e.g. Header: Value")
    end
  end
  headers
end
@headers = headers_array_to_hash(options[:headers])

url = ARGV[0]

bucket, key = S3CP.bucket_and_key(url)
fail "Your URL looks funny, doesn't it?" unless bucket

@s3 = S3CP.connect()

# copy all of STDIN to a temp file
temp = Tempfile.new('s3cp')
f = File.new("newfile2.zip",  "wb")
while true
  begin
    data = STDIN.sysread(4 * 1024)
    temp.syswrite(data)
  rescue EOFError => e
    break
  end
end
temp.close
temp.open

# upload temp file
begin
  @s3.interface.put(bucket, key, temp, @headers)
  STDERR.puts "s3://#{bucket}/#{key} => #{S3CP.format_filesize(temp.size)} "
ensure
  # cleanup
  temp.close
  temp.delete
end

