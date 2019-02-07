## 2019-02-06

Use the process dictionary for Raxx.Context.

This was due to the forseen cost in upgrading every project to take one extra argument in callbacks, particularly in the cases where the context was not going to be used.

## 2019-02-05

Don't implement default callbacks for behaviours, with debug information.

It is easier to work with the compiler warnings for an unimplemented callback,
than to define helper messages for each usecase.

[See discussion](https://elixirforum.com/t/should-libraries-implement-default-callbacks-that-are-intended-to-always-be-overwritten/19915)

## 2019-01-30

Choosing where code for extensions should reside.

1. Each in their own github repo
2. As a subdirectory in the Raxx project

Advantages of 1.
- CI with travis is simple, I don't know how to set up travis to only run tests on a subdirectory which changes, this option avoids this complexity.
- Someone else can start a Raxx extension in their own repo, this is still possible with 2 but the ones in Raxx project may feel "blessed".

Advantages of 2.
- Simpler contribution for fixes that apply to multiple projects
- One place for myself, and other contributors to go to look for open issues.
- Easy first place to look for things you might expect like CORS or Sessions.
- New features can be added to the core extensions in one PR
- mix can still depend on projects from github using the sparse options. `{:raxx_static, github: "crowdhailer/raxx_kit", branch: "runtime-static-middleware", sparse: "extensions/raxx_static"}`
