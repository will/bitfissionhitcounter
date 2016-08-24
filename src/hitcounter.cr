require "http/server"
require "pg"

DB = PG.connect(ENV["DATABASE_URL"]? || "postgres:///")

class IPTracker
  SIZE = 10

  def initialize
    @deq = Deque(String).new(SIZE)
    @m = Mutex.new
  end

  def check(ip)
    return true unless ip

    @m.synchronize do
      if @deq.includes?(ip)
        return false
      else
        @deq.shift if @deq.size >= SIZE
        @deq << ip
        return true
      end
    end
  end
end

def nextval
  DB.exec({Int64}, "select nextval('hitcounter')").rows.first.first
end

def currval
  DB.exec({Int64}, "select currval('hitcounter')").rows.first.first
end

tracker = IPTracker.new

port = (ENV["PORT"]? || 8080).to_i
server = HTTP::Server.new("0.0.0.0", port) do |context|
  ip = context.request.headers["X-Forwarded-For"]?
  count = tracker.check(ip) ? nextval : currval
  res = context.response
  res.content_type = "application/json"
  #  res.headers.add("Access-Control-Allow-Origin", "*")
  res.headers.add("Access-Control-Allow-Origin", "http://bitfission.com")
  res.headers.add("Access-Control-Allow-Methods", "GET")
  res.print %({"count": "#{count.to_s}"})
end

puts "listening on #{port}"
server.listen
