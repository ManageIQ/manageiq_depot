If you ask yourself the following:

> “How can I make a service with multiple service items, but then
conditional drop some during the deployment?”

...then this is the extension for you!

---

Eg. You have a Service Dialog like this one here;

[Download Sample Dialog](scripts/Sample_Dialog.yaml)

![Screen Shot 2014-10-10 at 14.11.00](images/screen-shot-2014-10-10-at-14-11-00.png)

Giving the user the option to select QA, Test or Production.

The decision would evaluate to one of 3 backing Service Items. Shown
here in this diagram;

![Slide1](images/slide1.png)

Each service item here maybe RHEV, OpenStack or VMware. They might be
all AWS/EC2 but different AMI’s etc!

So back to the use case,

How do I remove the service items I do not want to use from the service
bundle (Nobody mention ZSTOP!)

Lets go through the solution;

- You need to have a state machine for EACH service item. It can be the same state machine, but either way you need to specify one.

So, when you create each service item, and I am not concerned with the
contents here (EC2, RHOS, RHEV, VMware etc..) You need to specify an
entry point to a state machine that you have edit rights to as show
here;

![Screen Shot 2014-10-10 at 14.10.36](images/screen-shot-2014-10-10-at-14-10-36.png)

![Screen Shot 2014-10-10 at 14.10.49](images/screen-shot-2014-10-10-at-14-10-49.png)

![Screen Shot 2014-10-10 at 14.10.43](images/screen-shot-2014-10-10-at-14-10-43.png)

The bundle that has these three service items can be whatever you like,
here is mine, its just using its own state machine as you should do, but
nothing special happening here.

![Screen Shot 2014-10-10 at 14.10.24](images/screen-shot-2014-10-10-at-14-10-24.png)

So looking at the Automate browser what do these state machines look
like in file view?

![Screen Shot 2014-10-10 at 20.13.35](images/screen-shot-2014-10-10-at-20-13-35.png)

- The state machine has many steps, Pre1, Pre2, Pre3, Provisioin, Post
Provision etc.. We want to edit Pre1 and put something for the state
machine to process. We are going to call out to a method that decides to
either keep this service item or to dump it out. So exactly like a
conditional processor but done using some simple ruby code rather than
the nice GUI’s we see in Control, Reporting and Filtering (That may come
later in ManageIQ hopefully)

The code simply takes the value from the Dialog for an attribute. In my
case it is `Dialog_Environment`, the possible outcomes for this
attribute are `Test`, `QA`, or `Production`

The next thing we do is take the value of the state machine we are
running, so I have added to the state machine schema an Attribute field
called `State_Environment`. Now I know what the user selected and what
the current service I am running is.

So you should edit the schema of the
`\<YourDOMAIN>/Service/Provisioning/StateMachines/ServiceProvision_Template`
class to include this new attribute called `State_Environment` here is
a picture to show you the finished edit;

![Screen Shot 2014-10-10 at 20.20.31](images/screen-shot-2014-10-10-at-20-20-31.png)

If the value of Dialog_Environment is NOT same as State_Environment
then we want to dump this Service Item.

Here is the method; Its called Stopper, its a state on each of the
Service Item State Machines, I shall show you this next;

-----------------------------------------------------------------------

"Stopper" scripts:

```ruby
def mark_task_invalid(task)
 task.finished("Invalid")
 task.miq_request_tasks.each do |t|
 2.times { $evm.log("info", "********************************DUMPING TASK #{t}*************************************") }
 mark_task_invalid(t)
 end
end

10.times { $evm.log("info", "*********************************************************************") }

stp_task = $evm.root["service_template_provision_task"]
miq_request_id = $evm.vmdb('miq_request_task', stp_task.get_option(:parent_task_id))
dialogOptions = miq_request_id.get_option(:dialog)

$evm.log("info", "Dialog_Environment #{dialogOptions['dialog_environment'].downcase}")
$evm.log("info", "State_Environment #{$evm.root['State_Environment'].downcase}")

if dialogOptions['dialog_environment'].downcase != $evm.root['State_Environment'].downcase
  $evm.log("info", "NO MATCH - DUMPING Service from resolution")
  task = $evm.root["service_template_provision_task"]
  mark_task_invalid(task)
  exit MIQ_STOP
end

$evm.log("info", "MATCH FOUND - Processing Service Normally")

10.times { $evm.log("info", "*********************************************************************") }
```

Download the [Stopper method here](scripts/Stopper.rb)

So, the Stopper method needs to be placed somewhere, I instructed you do
this on the Pre1 of EACH service item state machine. Here is an example
of the QA state machine, this is the entry point for the service item
QA. I have used the ON_ENTRY state, but you must leave the other states
intact, you will see why in point number 3 coming next.

![Screen Shot 2014-10-10 at 20.16.30](images/screen-shot-2014-10-10-at-20-16-30.png)

- Now we do have a small issue to deal with, notice in the previous
step the code exit is MIQ_STOP. This is great on one hand because it
stops this state machine processing any further, but breaks in another
as the ae_result is populated with `error` and when the bundle starts
to look at its children for status it sees `error` and barfs out the
entire Service Bundle, not good. So we have to fake the ae_result back
to OK once we know that the reason for being `Error` is because we want
it to be and not because its a genuine error. Make sense?

So we have an OOTB method called `update_serviceprovision_status`, its
the job of this method to watch the service deployments and bump the
return status around depending on its value. In here we simply do a
check to say;

Is the item we are looking at for status, have a status value of
`Invalid`, because this is unique and not a Cloudforms status, its been
set specially by us for this use case. If it is `Invalid` then we know
that this service needs its `ae_result` forced to be `ok` and to exit
`MIQ_OK`. Making everyone happy, the service bundle thinks its
provisioned the service when it actually did not, moving onto the next
service item in the bundle.

Here is the _new_ `check_provision` method that you need to create in your
domain, I would simply copy the one from
`/ManageIQ/Service/Provisioning/StateMachines/ServiceProvision_Template/update_serviceprovision_status`

And either copy this code in, just place it near the top, before the
processing of the objects;

```ruby
# Bypass errors for Invalid instances
if prov.message == 'Invalid'
  $evm.log("info","Skipping Invalid Services")
  $evm.root['ae_result'] = 'ok'
  message = 'Service Provisioned Successfully'
  prov.finished(prov.message)
  exit MIQ_OK
end
```

or [download this new one from here](scripts/update_serviceprovision_status.rb)

I hope this all works for you, its a great use case and one we
talk about all the time.

Obviously there are more than one way to do this, but most other routes
either fail the bundle (bad) or require generic service items and loads
more code. This is re-usable, could be prodctised and easily repeatable
without a lot of effort. With the new domains in 3.1 you can have this
in your tool box.

I will raise a discussion on talk.manageiq.org to share this, and get
input on having the GUI conditional processor available in the Service
Item designer phase.
