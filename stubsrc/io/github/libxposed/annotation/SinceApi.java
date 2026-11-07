package io.github.libxposed.annotation;
import java.lang.annotation.*;
@Retention(RetentionPolicy.CLASS)
@Target({ElementType.METHOD, ElementType.CONSTRUCTOR, ElementType.FIELD, ElementType.TYPE, ElementType.PARAMETER})
public @interface SinceApi { int value(); }
