# To Do Items / Notes

## DONE Tracing

Steal from e2_debug and setup tracing on lpad modules if LPAD_TRACE_FILE env
var is set and non-0. This is better than peppering the code with logging.

## DONE Overwriting source files

The way we're requiring a "site" directory to avoid obliterating source files
is very dangerous. This is a bit tough, as we don't want implicit
behavior. E.g. we don't want to hard code a "site" directory that we generate
magically.

We also have this problem with the hard coding of "index.erl" as the index
file.

Hard-coded, implicit behavior is very un-Lambdapad.

Options:

- Look in .lpad for a config file that specifies the default index, the target
  directory, and any other options that might evolve here

- Two options to lpad-gen: INDEX_FILE and SITE_DIR

- Continue to hard-code index as the module and make it part of the site

### Define in .lpad/config

```erlang
#{
  index_module => index,
  site_root    => "site"
}.
```

I don't like this as it's starting to feel like these other generators that
have important config all over the place, hiding important information.

It also leaves the site definition looking like this:

```erlang
site(_) ->
    [{"index.html", {template, "index.html"}}].
```

Where does 'index.html' go? Who knows? In frustration you smash your
keyboard. It's not a good option.

### Args to lpad-gen

Same problem as with `.lpad/config`.

### Define in site/1

```erlang
site(_) ->
    {"site",
     [{"index.html", {template, "index.html"}}]}.
```

### Not a problem

The fact is that any top-level directory can point to source and end up
obliterating it. Let's keep it simple. This is pretty clear:

```erlang
site(_) ->
     [{"site/index.html", {template, "index.html"}}].
```

We could issue a warning if content (target) is written to the root directory,
as this is a bad idea.

I'm inclined to this option.

## DONE Custom Filters

It'd be easy to include index as a template filter module, making it possible
to do this:

```erlang
-module(index).

my_filter(Val) -> "I filter you: " ++ Val.
```

Use in a template:

```
{{ msg|my_filter }}
```

``index`` could also be extended to support:

```erlang
template_filters(_) -> [my_custom_filters].

## DONE List generator

We want to invoke another generator for each item in a list. Something like
this:

```erlang
data(_) -> #{colors => [red, blue, green]}.

site(_) -> #{ "site/{{item}}.html" => {map_template, "color.html"} }
```

## Custom Loaders and Generators

We could introduce a phase in the site generation for custom loaders and
generators as well as filters (above). Each could be a separate function or
perhaps a single function with a type arg.

Or the index itself could define handle_data_spec and handle_generator_spec.

## Consistent Samples

Some samples use property lists for site, some use maps.

## List base templates as sources

If index.html extends base.html, then any targets that depend on index.html
also depend on base.html.

## Create an index for samples

On make samples, use an index.erl to create an index.html that has links to
each of the samples.

## DONE Support trace patterns for functions

Look for MOD[:FUN[/ARITY]] pattern in LPAD_TRACE env and setup tracing
accordingly.

## DONE Data loader filters and maps

We need to support filters and maps at the data loader spec level. There's
currently no way to do this, short of a template filter, or hacking the "vars"
going into a generator, or filtering the list going into a template map.

E.g

    {apply, fun filter/1, {markdown, "speakers/*.md"}}

## Investigate index filter getting called twice when used from template

To recreate, create a filter that prints to stdout in index.erl and include it
once in a template. On lpad-gen it outputs twice. Why?

## Smarter data dependencies for templates

This is a hard problem. Atm, templates specify the generic `'$data'`
dependency, which makes them dependent on *all* data sources, not just the ones
they actually use.

But how do we know what sources a template actually uses? These sources come by
way of a single context value, which is made of up all the data sources. We'd
need to be very smart about tracking values that are used by the template and
deference their sources.

As it stands now, a change to a single *.md file will cause a regeneration of
all template content. This is terrible behavior. I'd expect just the effected
targets to be regenerated.

This is a tough one. I *think* we need to hack the template generator scheme
collect (or broadcast) the `__file__` values of objects are they're "read"
(e.g. wrap in a function call so we know when the value is accessed). If the
template can be hacked, that's ideal --- otherwise we'd need to use a side
effect to broadcast an association between the generated content and the
sources (broadast would be an awful hack --- look for template mod
alternative).

Another, much much easier approach, would be to let a template denote that it
requires "data" in general --- i.e. put this problem on the user. The downside
is that the user has to deal with this. The upside is that it avoids a lot of
complexity and ever increasingly "magical" behavior.

## Error Messages

As much fun as it is to use Erlang, it's not fun to figure out what this means:

```
=== ERROR ===
{{template_compile,"/home/garrett/SCM/chicago-erlang-2014/templates/index.html",
                   {"/home/garrett/SCM/chicago-erlang-2014/templates/index.html",
                    [{102,erlydtl_scanner,"Illegal character in column 24"}]}},
 [{lpad_template,handle_compile,3,[{file,"src/lpad_template.erl"},{line,43}]},
  {lpad_template,render,3,[{file,"src/lpad_template.erl"},{line,28}]},
  {lpad,generate,2,[{file,"src/lpad.erl"},{line,175}]},
  {lpad,run,2,[{file,"src/lpad.erl"},{line,37}]},
  {erl_eval,local_func,5,[{file,"erl_eval.erl"},{line,544}]},
  {escript,interpret,4,[{file,"escript.erl"},{line,781}]},
  {escript,start,1,[{file,"escript.erl"},{line,276}]},
  {init,start_it,1,[]}]}
```

And another (will require that we generate an exception that has the template
source name, in addition to the other info):

```
=== ERROR ===
{{file_read,"hello.markdown",enoent},
 [{lpad_template_filters,handle_file_read,2,
      [{file,"src/lpad_template_filters.erl"},{line,72}]},
  {'/home/garrett/SCM/lambdapad/samples/hello/index.html',render_internal,2,
      []},
  {'/home/garrett/SCM/lambdapad/samples/hello/index.html',render,2,[]},
  {lpad_template,render,2,[{file,"src/lpad_template.erl"},{line,46}]},
  {lpad_template,render,3,[{file,"src/lpad_template.erl"},{line,29}]},
  {lpad,generate,2,[{file,"src/lpad.erl"},{line,178}]},
  {lpad,run,2,[{file,"src/lpad.erl"},{line,37}]},
  {erl_eval,local_func,5,[{file,"erl_eval.erl"},{line,544}]}]}
```

Refer to lpad_event:handle_error/1 for how to print errors non stupidly.

## DONE Export all in index.erl considered bad

What happens to unused functions? They sit in the index as litter.

We should have an option to lpad-gen (or an env var,
e.g. LPAD_INDEX_REQUIRE_EXPORT) that causes export_all to be dropped when
compiling the index.

## Maps versus Proplists

With the new `apply` support, it's clearer than every that we can't cleanly
support maps and proplists as if they're the same thing. An original goal was
to support maps in addition to proplists --- maps have slightly less line noise
than proplists.

It'd be nice to let the dev decide and not ever perform a plist:conver_maps
operation - this would avoid surprise data conversions in applies and template
filters.

I think the main problem is that erlydtl doesn't like maps.

Let's keep an eye on this:

https://github.com/erlydtl/erlydtl/pull/170

## Caching apply results

The apply data spec is nice --- we can cache results and avoid potentially
costly operations.

## Need some unit tests

It's a bit risky at this point to refactor without some tests in place.

## Move to map base specs

Erlang terms-as-specs are notoriously hard to read.

Consider this:

```erlang
{template_map, "templates/foo.html",
  {foo, Foos},
  #{root => "../../",
    active_menu => "foos"}}
```

Sorry, this is just hard to read, even for someone who has a chance of knowing
what it's supposed to mean.

This is better:

```erlang
#{template    => "templates/foo.html",
  map_list    => Foos,
  map_item    => foo,
  root        => "../../",
  active_menu => "foos"}
```

This is the sort of thing you'd see in venerable JavaScript. It's far more
self-documenting. Less idiomatic Erlang though. But maybe that's just because
maps are new.

The problem this introduces is the collision of the "extra" attributes --- in
this case `root` and `active_menu`, which would be passed through to the
template as context. But this is not a general problem, it's specific to the
way the template generator would work. This could be worked-around by
supporting an explicit `context` or `extra_data` attribute.

For the time being, this feature will be implemented in `lpad_future` to
experiment without forcing a big refactor of the generators.

## Provide data context to filters

It'd be nice to provide data to filter. A case here is where one data
item references another. For example, a conference "talk" might
contain a reference to the "speaker" giving the talk. A filter could
be used to lookup a speaker for a given talk:

```
{% with speaker=talk|speaker_for_talk %}
The speaker's name is {{speaker.name}}
{% endwith %}
```

The filter though looks like this:

```erlang
speaker_for_talk(Talk) ->
    SpeakerId = plist:value("speaker", Talk),
    %% Now what? It'd be nice to have access to data here!
    [].
```

The best case here is something like this:

```erlang
speaker_for_talk(Talk, Context) ->
    SpeakerId = plist:value("speaker", Talk),
    Data = plist:value(data, Context),
    Speakers = plist:value(speakers, Data),
    find_speaker(SpeakerId, Speakers).
```

However, the second argument is already designated as the string
argument passed to the filter.

One option here is to use lpad_session.

The problem here is that we're now getting away from what makes using
Erlang in the first place a Good Thing - functional
patterns. lpad_session:root/0 is defensible as it's application
context that's set initially and then unchanged. There's no race
condition to worry about, etc. It's essentially global constant data.

If we exposes 'data' through the session, we have a race to ensure
that data is created before it's used. I'd rather not have to think
about those sort of problems and I'd rather not introduce magic
context, if it can be avoided.

Another option is to support an arity-3 function. We'd need to hack or
otherwise patch the current Erlydtl behavior to look for exported
arity-3 functions and:

- Always provide Context as the third arg
- If an arg was provided to the filter, provide it as the second arg
- If an arg was not provided to the filter, use the undefined atom as
  the second arg

I prefer this second form, though it does require that we break into
the template framework.

UPDATE: This request isn't needed. You can do this:

```
{% with speaker=talks|talks_for_speaker:speaker %}
The speaker's name is {{speaker.name}}
{% endwith %}
```

The filter though looks like this:

```erlang
speaker_for_talk(Talks, Speaker) ->
    lists:filter(fun(Talk) -> is_speaker_talk(Talk, Speaker) end, Talks).

This is right, the other thinking is wrong --- a filter in this case
is transforming something, filtering it, etc. and not using it to
lookup values from some global context.

## Impossible to have multiple generators for the same target

This is broken:

```erlang
site(Data) ->
    #{
      "site/images/" => {files, "speaker-images/*"},
      "site/images/" => {files, "articles/*.{jpg,png,gif}"}
     }.
```

As the map simply drops the previous entry.

## Not handling unknown filters gracefully

Lpad says something like this:

```
=== TEMPLATE COMPILE ERROR ===
{unknown_filter,speaker_for_slot,2}
```

Little help - maybe a file and a line number?

## Acute Pain Points (Garrett, July 15 2015)

- The error messages from LambdaPad are absurdly bad - any error
  should give me a file and line number, at a minimum - a meaningful
  message not wrapped in Erlang syntax would be nice too

- The lack of detecting changes in inherited or included files
  generates more pain for me than anything on the whole world

- Not being able to reuse anything without copying is the second most
  painful thing on the whole world

- We need more examples that are easy - the sense of payoff so far is
  like, "hey, this is Erlang so it's going to be super hard and take
  forever, but I'll have this smug sense of accomplishment in the end"

- Less of an issue, but at this point a raging deficiency is the use
  of proplists internally rather than maps. The most annoying part of
  this is that the data is presented as a proplist to template
  handlers - incredibly wrong! (Update: the current behavior is driven
  by our use of an old pre-map version of Erlydtl!)

Lot of work here, but doable.

## Directory of config files

We should support a list of items defined by config files in a
directory - in the same way we support items defined in markdown
files.
