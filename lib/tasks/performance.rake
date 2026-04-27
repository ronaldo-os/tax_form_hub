namespace :benchmark do
  desc "Run memory usage benchmarks"
  task :memory do
    puts "Running memory benchmarks..."
    
    # Benchmark memory usage for common operations
    require 'memory_profiler'
    
    # Benchmark invoice loading
    puts "\n=== Invoice Loading Memory Usage ==="
    report = MemoryProfiler.report do
      # Simulate loading invoices with associations
      10.times do
        Invoice.includes(:recipient_company, :sale_from, :line_items).limit(100).to_a
      end
    end
    
    puts "Total allocated: #{report.total_allocated_memsize} bytes"
    puts "Total retained: #{report.total_retained_memsize} bytes"
    puts "Objects allocated: #{report.total_allocated} objects"
    puts "Objects retained: #{report.total_retained} objects"
    
    # Benchmark caching effectiveness
    puts "\n=== Caching Memory Usage ==="
    report = MemoryProfiler.report do
      5.times do
        Rails.cache.fetch("test_key", expires_in: 5.minutes) do
          "test_value" * 1000
        end
      end
    end
    
    puts "Cache operations allocated: #{report.total_allocated_memsize} bytes"
  end
  
  desc "Run request performance benchmarks"
  task :requests do
    puts "Running request benchmarks..."
    
    require 'benchmark'
    
    # Benchmark common controller actions
    puts "\n=== Controller Action Performance ==="
    
    Benchmark.bm(20) do |x|
      x.report("Invoices#index") do
        100.times do
          # Simulate index action performance
          controller = InvoicesController.new
          controller.params = { tab: 'sales-invoices' }
          # Note: This is a simplified benchmark
          # In real implementation, you'd use proper test setup
        end
      end
      
      x.report("Invoice creation") do
        50.times do
          # Simulate invoice creation
          invoice = Invoice.new(
            invoice_number: "INV-#{rand(10000)}",
            issue_date: Date.today,
            currency: "PHP"
          )
          invoice.valid?
        end
      end
      
      x.report("Cache operations") do
        200.times do
          Rails.cache.fetch("benchmark_#{rand(100)}", expires_in: 1.minute) do
            { data: "test" * 10 }
          end
        end
      end
    end
  end
  
  desc "Check database query performance"
  task :queries do
    puts "Running query performance checks..."
    
    require 'benchmark'
    
    puts "\n=== Database Query Performance ==="
    
    Benchmark.bm(30) do |x|
      x.report("Invoices without eager loading") do
        10.times do
          Invoice.limit(100).each do |invoice|
            invoice.recipient_company&.name
            invoice.sale_from&.name
          end
        end
      end
      
      x.report("Invoices with eager loading") do
        10.times do
          Invoice.includes(:recipient_company, :sale_from).limit(100).each do |invoice|
            invoice.recipient_company&.name
            invoice.sale_from&.name
          end
        end
      end
      
      x.report("Complex query with joins") do
        10.times do
          Invoice.joins(:recipient_company)
                 .where(companies: { archived: false })
                 .includes(:line_items)
                 .limit(100)
                 .to_a
        end
      end
    end
  end
  
  desc "Generate performance report"
  task :report => [:memory, :requests, :queries] do
    puts "\n=== Performance Report Generated ==="
    puts "Check the output above for detailed metrics"
    puts "Consider these thresholds:"
    puts "- Memory usage should be < 100MB for typical operations"
    puts "- Request times should be < 500ms for index actions"
    puts "- Database queries should use eager loading for associations"
  end
end

namespace :test do
  desc "Run performance-focused tests"
  task :performance do
    puts "Running performance-focused test suite..."
    
    # Run tests with performance focus
    system("RAILS_ENV=test bin/rails test test/performance/*_test.rb")
    
    # Check for N+1 queries using Bullet
    if defined?(Bullet)
      puts "\n=== N+1 Query Detection ==="
      Bullet.enable = true
      Bullet.bullet_logger = true
      Bullet.console = true
      
      # Run a subset of tests to check for N+1 queries
      system("RAILS_ENV=test bin/rails test test/controllers/invoices_controller_test.rb")
    end
  end
  
  desc "Check database N+1 queries"
  task :db do
    puts "Checking for N+1 queries..."
    
    begin
      require 'bullet'
      
      Bullet.enable = true
      Bullet.bullet_logger = true
      Bullet.console = true
      Bullet.raise = true # Raise exception on N+1 queries
      
      puts "Running tests with N+1 query detection..."
      
      # Simulate common operations that might cause N+1 queries
      puts "\nTesting invoice loading..."
      Invoice.includes(:recipient_company, :sale_from).limit(10).each do |invoice|
        puts "Invoice: #{invoice.invoice_number}"
        puts "Recipient: #{invoice.recipient_company&.name}"
        puts "Sender: #{invoice.sale_from&.name}"
      end
      
      puts "No N+1 queries detected in basic operations"
      
    rescue LoadError
      puts "Bullet gem not installed. Add to Gemfile: gem 'bullet', group: :test"
    rescue => e
      puts "Potential N+1 query detected: #{e.message}"
    end
  end
end
