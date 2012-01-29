require 'min_mail/version'
require 'min_mail/imap'
require 'mail'
require 'time'
require 'yaml'

class MinMail

    def extract_address(address_struct)
      address = if address_struct.nil?
                  "Unknown"
                else 
                  email = [ (address_struct.mailbox ? Mail::Encodings.unquote_and_convert_to(address_struct.mailbox, 'UTF-8') : ""), 
                      (address_struct.host ?  Mail::Encodings.unquote_and_convert_to(address_struct.host, 'UTF-8'): "")
                    ].join('@') 
                  if address_struct.name
                   "#{Mail::Encodings.unquote_and_convert_to((address_struct.name || ''), 'UTF-8')} <#{email}>"
                  else
                    email
                  end
                end

    end


  def initialize(opts)

    defaults = {
      mailbox: 'INBOX'
    }
    @opts = defaults.merge opts

  end

  def run
    if @opts[:uid]
      fetch @opts[:uid]
    else
      scan
    end
  end

  def scan 

    # fetches the last 20 msg
    
    Imap.new(@opts).with_open {|imap|
      imap.select @opts[:mailbox]
      ids = imap.search("all")
      ids.reverse!
      results = imap.fetch(ids[0,20], ["FLAGS", "ENVELOPE", "RFC822.SIZE", "UID"])
      results.map { |x| 

        envelope = x.attr["ENVELOPE"]
        message_id = envelope.message_id
        subject = Mail::Encodings.unquote_and_convert_to((envelope.subject || ''), 'UTF-8')
        recipients = ((envelope.to || []) + (envelope.cc || [])).map {|a| extract_address(a)}.join(', ')
        sender = extract_address envelope.from.first
        uid = x.attr["UID"]
        params = {
          uid: x.attr["UID"],
          subject: (subject || ''),
          flags: x.attr['FLAGS'].join(','),
          date: Time.parse(envelope.date).localtime.to_s,
          size: x.attr['RFC822.SIZE'],
          sender: sender,
          recipients: recipients
        }
        puts params.to_yaml
      }
    }
    
  end

  # fetch one message by uid
  def fetch uid
    Imap.new(@opts).with_open {|imap|
      imap.select(@opts[:mailbox])
      res = imap.uid_fetch(uid, ["FLAGS", "ENVELOPE", "RFC822.SIZE", "RFC822", "UID"])
      m = Mail.new(res[0].attr['RFC822'])
      puts m.body.decoded
    }
  end
end

if __FILE__ == $0
  opts = YAML::load File.read(ENV['HOME'] + "/vmail/.vmailrc")
  if ARGV[0]
    opts.merge! uid: ARGV[0].to_i
  end
  MinMail.new(opts).run

end
