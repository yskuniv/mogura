# frozen_string_literal: true

require "thor"
require "base64"

module Mogura
  class CLI < Thor
    desc "start HOST", "connect to HOST and start watching"
    option :port, type: :numeric, default: 143, aliases: :p
    option :starttls, type: :boolean, default: true
    option :use_ssl, type: :boolean, default: false
    option :auth_type, type: :string, default: "LOGIN"
    option :user, type: :string, aliases: :u
    option :password_base64, type: :string
    option :config, type: :string, aliases: :c, required: true
    option :target_mailbox, type: :string, aliases: :b, required: true
    def start(host)
      port = options[:port]
      starttls = options[:starttls]
      use_ssl = options[:use_ssl]
      auth_type = options[:auth_type] if use_ssl
      user = options[:user]
      password = Base64.decode64(options[:password_base64])
      config = options[:config]
      target_mailbox = options[:target_mailbox]

      raise NotImplementedError, "STARTTLS currently not supported" if !use_ssl && starttls

      warn "* parsing rules..."

      rules = RulesParser.parse(File.read(config))

      warn "* connecting the server..."

      imap_handler = IMAPHandler.new(host, port, usessl: true, certs: nil, verify: true,
                                                 auth_info: { auth_type: auth_type, user: user, password: password })

      warn "* start monitoring recent mails in \"#{target_mailbox}\""

      imap_handler.monitor_recents(target_mailbox) do |message_id|
        puts "mail (id = #{message_id} on #{target_mailbox}) is recent"

        filter_mail(target_mailbox, message_id)
      end
    end

    private

    def filter_mail(mailbox, message_id)
      puts "filtering mail (id = #{message_id} on #{mailbox})..."

      mail = imap_handler.fetch_header(mailbox, message_id)

      rules.each do |rule_set|
        dest_mailbox = rule_set.destination
        rule = rule_set.rule

        next unless RuleMatcher.match?(rule, mail)

        puts "mail \"#{mail}\" matches the rule: #{rule}"
        puts "moving mail \"#{mail}\" to #{dest_mailbox}"

        imap_handler.move(mailbox, message_id, dest_mailbox)
      end
    end
  end
end
