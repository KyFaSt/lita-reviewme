# lita-reviewme
[![Build Status](https://travis-ci.org/iamvery/lita-reviewme.svg?branch=master)](https://travis-ci.org/iamvery/lita-reviewme)

A [lita](https://www.lita.io/) handler that helps with [code review](http://en.wikipedia.org/wiki/Code_review)
without getting in the way.

The handler rotates, in order, through a list of names to provider a "reviewer"
for some unit of work.

## Installation

Add lita-reviewme to your Lita instance's Gemfile:

``` ruby
gem "lita-reviewme", github: "iamvery/lita-reviewme"
```

## Configuration

Environment variable needed for Github integration:

```
ENV["GITHUB_WOLFBRAIN_ACCESS_TOKEN"]
```

## Usage

### Add a review group

> **Kylie S.** Nerdbot: create backend, reviewers: iamvery, zacstewart
>
> **Nerdbot** created group backend with reviewers iamvery, zacstewart


### See who is in a group's review rotation.

> **Jay H.** Nerdbot: reviewers backend
>
> **Nerdbot** iamvery, zacstewart, ...

### Add a name to the review rotation

> **Jay H.** Nerdbot: add kyfast to web
>
> **Nerdbot** added kyfast to web

### Remove a name from the review rotation

> **Jay H.** Nerdbot: remove kyfast from web
>
> **Nerdbot** removed kyfast from web

### Fetch the next reviewer

> **Jay H.** Nerdbot: review me backend
>
> **Nerdbot** iamvery

### Comment on a Github pull request or issue
This will post a comment mentioning the next reviewer on the referenced Github
pull request or issue. In order for this to work, @wolfbrain must have access
to the repository.

> **Jay H.** Nerdbot: review backend https://github.com/iamvery/lita-reviewme/issues/7
>
> **Nerdbot** iamvery should be on it...

## License

[MIT](http://opensource.org/licenses/MIT)
