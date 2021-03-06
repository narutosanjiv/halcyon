describe "Halcyon::Controller" do
  
  before do
    @log = ''
    @logger = Logger.new(StringIO.new(@log))
    Halcyon.config.use do |c|
      c[:logger] = @logger
    end
    @app = Halcyon::Runner.new
  end
  
  it "should provide various shorthand methods for simple responses but take custom response values" do
    controller = Specs.new(Rack::MockRequest.env_for('/'))
    
    response = {:status => 200, :body => 'OK', :headers => {}}
    controller.ok.should == response
    controller.success.should == response
    
    controller.ok('').should == {:status => 200, :body => '', :headers => {}}
    controller.ok(['OK', 'Sure Thang', 'Correcto']).should == {:status => 200, :body => ['OK', 'Sure Thang', 'Correcto'], :headers => {}}
    
    headers = {'Date' => Time.now.strftime("%a, %d %h %Y %H:%I:%S %Z"), 'Test' => 'FooBar'}
    controller.ok('OK', headers).should == {:status => 200, :body => 'OK', :headers => headers}
  end
  
  it "should provide extensive responders" do
    controller = Specs.new(Rack::MockRequest.env_for('/'))
    
    should.raise(Halcyon::Exceptions::UnprocessableEntity) { controller.status(:unprocessable_entity) }
    response = Rack::MockRequest.new(@app).get("/specs/unprocessable_entity_test")
    response.body.should =~ %r{Unprocessable Entity}
    
    should.raise(Halcyon::Exceptions::UnprocessableEntity) { controller.status(:unprocessable_entity) }
  end
  
  it "should indicate service is unavailable if an status specified is not found" do
    controller = Specs.new(Rack::MockRequest.env_for('/'))
    should.raise(Halcyon::Exceptions::ServiceUnavailable) { controller.status(:this_state_does_not_exist) }
  end
  
  it "should provide a quick way to find out what method the request was performed using" do
    %w(GET POST PUT DELETE).each do |m|
      controller = Specs.new(Rack::MockRequest.env_for('/', :method => m))
      controller.method.should == m.downcase.to_sym
    end
  end
  
  it "should provide convenient access to GET and POST data" do
    controller = Specs.new(Rack::MockRequest.env_for("/#{rand}?foo=bar"))
    controller.get[:foo].should == 'bar'
    
    controller = Specs.new(Rack::MockRequest.env_for("/#{rand}", :method => 'POST', :input => {:foo => 'bar'}.to_params))
    controller.post[:foo].should == 'bar'
  end
  
  it "should parse URI query params correctly" do
    controller = Specs.new(Rack::MockRequest.env_for("/?query=value&lang=en-US"))
    controller.get[:query].should == 'value'
    controller.get[:lang].should == 'en-US'
  end
  
  it "should parse the URI correctly" do
    controller = Specs.new(Rack::MockRequest.env_for("http://localhost:4000/slaughterhouse/5"))
    controller.uri.should == '/slaughterhouse/5'
    
    controller = Specs.new(Rack::MockRequest.env_for("/slaughterhouse/5"))
    controller.uri.should == '/slaughterhouse/5'
    
    controller = Specs.new(Rack::MockRequest.env_for(""))
    controller.uri.should == '/'
  end
  
  it "should provide url accessor for resource index route" do
    controller = Resources.new(Rack::MockRequest.env_for("/resources"))
    controller.uri.should == controller.url(:resources)
  end
  
  it "should provide url accessor for resource show route" do
    resource = Model.new
    resource.id = 1
    controller = Resources.new(Rack::MockRequest.env_for("/resources/1"))
    controller.uri.should == controller.url(:resource, resource.id)
  end
  
  it "should accept response headers" do
    controller = Specs.new(Rack::MockRequest.env_for(""))
    headers = {'Date' => Time.now.strftime("%a, %d %h %Y %H:%I:%S %Z"), 'Foo' => 'Bar'}
    controller.ok('OK', headers).should == {:status => 200, :body => 'OK', :headers => headers}
    controller.ok('OK').should == {:status => 200, :body => 'OK', :headers => {}}
    
    response = Rack::MockRequest.new(@app).get("/goob")
    response['Date'].should == Time.now.strftime("%a, %d %h %Y %H:%I:%S %Z")
    response['Content-Language'].should == 'en'
  end
  
  it "should handle return values from actions not from the response helpers" do
    {
      'OK' => {'status' => 200, 'body' => 'OK'},
      [200, {}, 'OK'] => {'status' => 200, 'body' => 'OK'},
      [1, 2, 3] => {'status' => 200, 'body' => [1, 2, 3]},
      {'foo' => 'bar'} => {'status' => 200, 'body' => {'foo' => 'bar'}}
    }.each do |(value, expected)|
      $return_value_for_gaff = value
      response = JSON.parse(Rack::MockRequest.new(@app).get("/gaff").body).should == expected
    end
  end
  
  it "should run filters before or after actions" do
    response = Rack::MockRequest.new(@app).get("/index")
    response.body.should =~ %r{Found}
    
    # The Accepted exception is raised if +cause_exception_in_filter+ is set
    response = Rack::MockRequest.new(@app).get("/index?cause_exception_in_filter=true")
    response.body.should =~ %r{Accepted}
    
    response = Rack::MockRequest.new(@app).get("/foobar")
    response.body.should =~ %r{fubr}
    
    # The Created exception is raised if +cause_exception_in_filter+ is set
    response = Rack::MockRequest.new(@app).get("/foobar?cause_exception_in_filter=true")
    response.body.should =~ %r{Created}
    
    response = Rack::MockRequest.new(@app).get("/hello/Matt?cause_exception_in_filter_block=true")
    response.body.should =~ %r{Not Found}
  end
  
end
