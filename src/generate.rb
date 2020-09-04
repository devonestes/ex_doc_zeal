require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri'
end

def check_doc_type(doc)
  mod = doc.css('#moduledoc')
  exception = doc.css('#content > h1 > small:nth-child(2):contains("exception")')
  protocol = doc.css('#content > h1 > small:nth-child(2):contains("protocol")')
  mix_task = doc.css('#content > h1:contains("mix ")')
  mod = doc.css('#moduledoc')
  if !exception.empty?
    :exception
  elsif !protocol.empty?
    :protocol
  elsif !mix_task.empty?
    :mix_task
  elsif !mod.empty?
    :public_module
  else
    :undefined
  end
end

def run(file_name)
  puts "CREATE TABLE IF NOT EXISTS searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);"
  doc = Nokogiri::HTML(ARGF.read)
  case check_doc_type(doc)
  when :exception then
    handle_exception(doc, file_name)
  when :protocol then
    handle_protocol(doc, file_name)
  when :mix_task then
    handle_mix_task(doc, file_name)
  when :public_module then
    handle_module(doc, file_name)
  end
end

def handle_module(doc, file_name)
  text = doc.css("#content > h1").first.text.strip!

  matches = text.match(/[a-zA-Z]* v[0-9\.]*\n *([a-zA-Z\. ]*)\n/)
  mod = if matches
          matches.captures.first.strip.delete_suffix(' behaviour')
        else
          text.match(/[a-zA-Z]* v[0-9\.]*\n *([a-zA-Z\. ]*)/).captures.first.strip.delete_suffix(' behaviour')
        end

  puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{mod}', 'Module', '#{file_name}');"

  handle_functions(doc, mod, file_name)
  handle_types(doc, mod, file_name)
  handle_callbacks(doc, mod, file_name)
end

def handle_functions(doc, mod, file_name)
  doc.css('.functions-list > .detail').each do |fun_name|
    fun = fun_name.attr('id')
    if !fun_name.css('span.note:contains("(macro)")').empty?
      puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{mod}.#{fun}', 'Macro', '#{file_name}##{fun}');"
    else
      puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{mod}.#{fun}', 'Function', '#{file_name}##{fun}');"
    end
  end
end

def handle_types(doc, mod, file_name)
  doc.css('.types-list > .detail').each do |type_name|
    type = type_name.attr('id').delete_prefix('t:')
    puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{mod}.#{type}', 'Type', '#{file_name}#t:#{type}');"
  end
end

def handle_callbacks(doc, mod, file_name)
  doc.css('.callbacks-list > .detail').each do |callback_name|
    callback = callback_name.attr('id').delete_prefix('c:')
    puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{mod}.#{callback}', 'Callback', '#{file_name}#c:#{callback}');"
  end
end

def handle_exception(doc, file_name)
  mod = doc.css("#content > h1").first.text.strip!
           .match(/[a-zA-Z]* v[0-9\.]*\n *([a-zA-Z\. ]*)\n/)
           .captures.first.strip.delete_suffix(' exception')
  puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{mod}', 'Exception', '#{file_name}');"
end

def handle_protocol(doc, file_name)
  mod = doc.css("#content > h1").first.text.strip!
           .match(/[a-zA-Z]* v[0-9\.]*\n *([a-zA-Z\. ]*)\n/)
           .captures.first.strip.delete_suffix(' protocol')
  puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{mod}', 'Protocol', '#{file_name}');"
end

def handle_mix_task(doc, file_name)
  task = doc.css("#content > h1").first.text.strip!
            .match(/[a-zA-Z]* v[0-9\.]*\n *([a-zA-Z\. ]*)\n/)
            .captures.first.strip!
  puts "INSERT INTO searchIndex(name, type, path) VALUES ('#{task}', 'Mix Task', '#{file_name}');"
end

file_name = ARGV.first

run(file_name)
