<!-- # Gush [![Build Status](https://travis-ci.org/chaps-io/gush.svg?branch=master)](https://travis-ci.org/chaps-io/gush) -->

<!-- ## [![](http://i.imgur.com/ya8Wnyl.png)](https://chaps.io) proudly made by [Chaps](https://chaps.io) -->

[![Build Status](https://travis-ci.com/RnD-Soft/burstflow.svg?branch=master)](https://travis-ci.com/RnD-Soft/burstflow) [![Gem Version](https://badge.fury.io/rb/burstflow.svg)](https://badge.fury.io/rb/burstflow)

Burstflow is a parallel workflow runner using [ActiveRecord] and [ActiveJob](https://guides.rubyonrails.org/v4.2/active_job_basics.html) for scheduling and executing jobs.

This gem is higly inspired by [Gush](https://github.com/chaps-io/gush). But not tied to Reddis or Sidekiq like Gush.

ActiveRecord used as persisted store during workflow execution.

Additional features:

* **susped** and **resume** job(and whole workflow). For example if your job makes asynchronous request and will receive a response some time later. In this case, the job can send request and suspend until some external event resumes it eventually.
* before/after callbacks on jobs level
* before/after callbacks on workflow level
* **Dynamic workflows**. Any job can produce another jobs while executing. This jobs has its parent as incomming jobs, and all parents outgoing jobs as own outgoings.


## Installation

### 1. Add `burst` to Gemfile

```ruby
gem 'burstflow', '~> 0.2.0'
```

### 2. Run migrations

```rake burstflow:install:migrations```

## Example

The DSL for defining jobs consists of a single `run` method.
Here is a complete example of a workflow you can create:

```ruby
# app/workflows/sample_workflow.rb
class SampleWorkflow < Burstflow::Workflow
  configure do |url_to_fetch_from|
    run FetchJob1, params: { url: url_to_fetch_from }
    run FetchJob2, params: { some_flag: true, url: 'http://url.com' }

    run PersistJob1, after: FetchJob1
    run PersistJob2, after: FetchJob2

    run Normalize,
        after: [PersistJob1, PersistJob2],
        before: Index

    run Index
  end
end
```

and this is how the graph will look like:

![SampleWorkflow](https://i.imgur.com/DFh6j51.png)


## Defining workflows

Let's start with the simplest workflow possible, consisting of a single job:

```ruby
class SimpleWorkflow < Burstflow::Workflow
  configure do 
    run DownloadJob
  end
end
```

Of course having a workflow with only a single job does not make sense, so it's time to define dependencies:

```ruby
class SimpleWorkflow < Burst::Workflow
  configure do
    run DownloadJob
    run SaveJob, after: DownloadJob
  end
end
```

We just told Burstflow to execute `SaveJob` right after `DownloadJob` finishes **successfully**.

But what if your job must have multiple dependencies? That's easy, just provide an array to the `after` attribute:

```ruby
class SimpleWorkflow < Burstflow::Workflow
  configure do
    run FirstDownloadJob
    run SecondDownloadJob

    run SaveJob, after: [FirstDownloadJob, SecondDownloadJob]
  end
end
```

Now `SaveJob` will only execute after both its parents finish without errors.

With this simple syntax you can build any complex workflows you can imagine!

#### Alternative way

`run` method also accepts `before:` attribute to define the opposite association. So we can write the same workflow as above, but like this:

```ruby
class SimpleWorkflow < Burstflow::Workflow
  configure do
    run FirstDownloadJob, before: SaveJob
    run SecondDownloadJob, before: SaveJob

    run SaveJob
  end
end
```

You can use whatever way you find more readable or even both at once :)

### Passing arguments to workflows

Workflows can accept any primitive arguments in their constructor, which then will be available in your
`configure` method.

Let's assume we are writing a book publishing workflow which needs to know where the PDF of the book is and under what ISBN it will be released:

```ruby
class PublishBookWorkflow < Burstflow::Workflow
  configure do |url, isbn|
    run FetchBook, params: { url: url }
    run PublishBook, params: { book_isbn: isbn }, after: FetchBook
  end
end
```

and then create your workflow with those arguments:

```ruby
PublishBookWorkflow.build("http://url.com/book.pdf", "978-0470081204")
```

and that's basically it for defining workflows, see below on how to define jobs:

## Defining jobs

The simplest job is a class inheriting from `Burstflow::Job` and responding to `perform` and `resume` method. Much like any other ActiveJob class.

```ruby
class FetchBook < Burst::Job
  def perform
    # do some fetching from remote APIs
  end
end
```

But what about those params we passed in the previous step?

## Passing parameters into jobs

To do that, simply provide a `params:` attribute with a hash of parameters you'd like to have available inside the `perform` method of the job.

So, inside workflow:

```ruby
(...)
run FetchBook, params: {url: "http://url.com/book.pdf"}
(...)
```

and within the job we can access them like this:

```ruby
class FetchBook < Burst::Job
  def perform
    # you can access `params` method here, for example:

    params #=> {url: "http://url.com/book.pdf"}
  end
end
```

## Executing workflows

Workflows are executed by any backend you chose for ActiveJob.


### 1. Create the workflow instance

```ruby
flow = PublishBookWorkflow.build("http://url.com/book.pdf", "978-0470081204")
```

### 2. Start the workflow

```ruby
flow.start!
```

Now Burstflow will start processing jobs in the background using ActiveJob and your chosen backend.

### 3. Monitor its progress:

```ruby
flow.reload
flow.status
#=> :running|:finished|:failed|:suspended
```

`reload` is needed to see the latest status, since workflows are updated asynchronously.

## Advanced features

### Pipelining

Burstflow offers a useful tool to pass results of a job to its dependencies, so they can act differently.

**Example:**

Let's assume you have two jobs, `DownloadVideo`, `EncodeVideo`.
The latter needs to know where the first one saved the file to be able to open it.


```ruby
class DownloadVideo < Burst::Job
  def perform
    downloader = VideoDownloader.fetch("http://youtube.com/?v=someytvideo")

    output(downloader.file_path)
  end
end
```

`output` method is used to ouput data from the job to all dependant jobs.

Now, since `DownloadVideo` finished and its dependant job `EncodeVideo` started, we can access that payload inside it:

```ruby
class EncodeVideo < Burstflow::Job
  def perform
    video_path = payloads.first[:value]
  end
end
```

`payloads` is an array containing outputs from all ancestor jobs. So for our `EncodeVide` job from above, the array will look like:


```ruby
[
  {
    id: "DownloadVideo-41bfb730-b49f-42ac-a808-156327989294" # unique id of the ancestor job
    class: "DownloadVideo",
    value: "https://s3.amazonaws.com/somebucket/downloaded-file.mp4" #the payload returned by DownloadVideo job using `output()` method
  }
]
```

**Note:** Keep in mind that payloads can only contain data which **can be serialized as JSON**.

### Dynamic workflows

There might be a case when you have to construct the workflow dynamically depending on the input.

As an example, let's write a workflow which accepts an array of users and has to send an email to each one. Additionally after it sends the e-mail to every user, it also has to notify the admin about finishing.


```ruby

class ParentJob < Burstflow::Job
  def perform
    configure do 
      params[:user_ids].map do |user_id|
        run NotificationJob, params: {user_id: user_id}
      end
    end
  end
end

class NotifyWorkflow < Burst::Workflow
  configure do |user_ids|
    run ParentJob, params: {user_ids: user_ids}

    run AdminNotificationJob, after: ParentJob
  end
end
```



## Original Gush Contributors

https://github.com/chaps-io/gush#contributors

## Contributing

1. Fork it ( https://github.com/RnD-Soft/burstflow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
