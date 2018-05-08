require "http/server"
require "pg"

PDB = PG.connect(ENV["DATABASE_URL"]? || "postgres:///")

class IPTracker
  SIZE = 10

  def initialize
    @deq = Deque(String).new(SIZE)
    @m = Mutex.new
  end

  def check(ip)
    return true unless ip
    ip = ip.split(",").last

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

class Counter
  getter count : Int64

  def initialize
    @count = PDB.query_one("select count from hits limit 1", &.read(Int64))
    @m = Mutex.new
    async_save_loop
  end

  def inc
    @m.synchronize { @count += 1 }
    @count
  end

  private def save
    PDB.exec("update hits set count = $1", [count])
  end

  private def async_save_loop
    spawn do
      loop do
        sleep 1
        save
      end
    end
  end
end

tracker = IPTracker.new
counter = Counter.new

port = (ENV["PORT"]? || 8080).to_i
server = HTTP::Server.new("0.0.0.0", port) do |context|
  ip = context.request.headers["X-Forwarded-For"]?
  count = tracker.check(ip) ? counter.inc : counter.count
  res = context.response
  res.content_type = "application/json"
  #  res.headers.add("Access-Control-Allow-Origin", "*")
  res.headers.add("Access-Control-Allow-Origin", "http#{'s' if context.request.headers["Origin"][4] == 's'}://bitfission.com")
  res.headers.add("Access-Control-Allow-Methods", "GET")
  res.print %({"count": "#{count.to_s}"})
end

puts "listening on #{port}"
server.listen
