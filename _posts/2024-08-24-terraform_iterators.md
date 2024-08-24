---
title: "Terraform iterators"
date: 2024-08-24

toc: true
toc_sticky: true
toc_label: Table of content

excerpt: Become a pro using iteration in terraform to create better modules.

tags:
    - terraform
---

Iteration in terraform has been around for a while now, and it's very powerful, but do you know how to use it correctly?

In this post we will explore some basuc concepts about it and use some real examples to showcase how they can allow us to make better and more readable terraform code.

## Why do we need to iterate?

As you must already know, Terraform is a declarative language that allows us to describe infrastructure via `resources`. But more often than expected, the resources we need to create are not one, but a set of similar resources based on a variable we define or even an output from other resource created by the same code we are generating.

In these cases, we are provided with two `metatags` available in all resources (and even modules): `count` and `for_each`, which will tell terraform to create more than one of the objects described by iterating, and exposing an iterator inside the resource so we can correctly set the attributes of it.