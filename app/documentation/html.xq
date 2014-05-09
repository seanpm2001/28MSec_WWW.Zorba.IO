xquery version "3.0";

(:
 : Copyright 2008-2011 The FLWOR Foundation.
 :
 : Licensed under the Apache License, Version 2.0 (the "License");
 : you may not use this file except in compliance with the License.
 : You may obtain a copy of the License at
 :
 : http://www.apache.org/licenses/LICENSE-2.0
 :
 : Unless required by applicable law or agreed to in writing, software
 : distributed under the License is distributed on an "AS IS" BASIS,
 : WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 : See the License for the specific language governing permissions and
 : limitations under the License.
:)

(:~
 : Convert an XQDoc document into an HTML document.
 :
 : This module contains a single <code>convert()</code> function
 : that transform an XQDoc document into an HTML document.
 : Usage:
 : <pre class="ace-static" ace-mode="xquery">
 : let $xqdoc := xqdoc:xqdoc("http://expath.org/ns/file")
 : return html:convert($xqdoc)
 : </pre>
 :
 : @author William Candillon <a href="#">wcandillon at gmail dot com</a>
 :
 :)

module namespace html = "http://www.zorba-xquery.com/modules/xqdoc/html";

declare namespace xq = "http://www.xqdoc.org/1.0";
declare namespace o = "http://www.w3.org/2010/xslt-xquery-serialization";

declare copy-namespaces no-preserve, inherit;

declare %private variable $html:empty-tags-to-delete := ("tt");

declare function html:convert($xqdoc as element(xq:xqdoc))
as element(div)
{
let $module := $xqdoc/xq:module
let $ns := normalize-space($module/xq:uri/text())
let $comment := $module/xq:comment
let $namespaces := $module/xq:custom[@tag = "namespaces"]/xq:namespace
let $prefix := $xqdoc/xq:functions/xq:function[1]/xq:name/text()/substring-before(., ":")
let $prefix := if(exists($prefix)) then $prefix else $xqdoc/xq:variables/xq:variable[1]/xq:uri/text()/substring-before(., ":")
let $variables := for $variable in $xqdoc/xq:variables/xq:variable[not(.//xq:annotation/@localname = "private")] order by $variable/xq:name/text() ascending return $variable
let $functions := for $function in $xqdoc/xq:functions/xq:function[not(html:is-function-private(.))] order by concat($function/xq:name/text(), $function/@arity) ascending return $function
let $description := $comment/xq:description/node()
return
html:normalize(
<div>
  <h1>Module</h1>
  <p class="namespace">{$ns}</p>
  <section id="description">
    <h2>Description</h2>
    {
      if($description instance of text()) then
        <p>{$description}</p>
      else
        $comment/xq:description/node()
    }
    {
      let $sees := $comment/xq:see
      return
        if(exists($sees)) then
          <section>
          <h4>References</h4>
          {
            for $see in $sees
            return <p>{$see/node()}</p>
          }
          </section>
        else ()
    }
    {
      let $authors := $comment/xq:author
      return
        if(exists($authors)) then
         <section>
           <h4>{concat("Author", if(count($authors) gt 1) then "s" else "")}</h4>
           {
             for $author in $authors
             return <p>{$author/node()}</p>
           }
         </section>
        else ()
    }
    {
      let $version  := $comment/xq:custom[@tag =  "XQuery version"]/text()
      let $encoding := $comment/xq:custom[@tag = "encoding"]/text()
      return
        if(exists($version)) then
          <section>
            <h4>XQuery version and encoding</h4>
            <pre class="ace-static" ace-mode="xquery">xquery version "{$version}"{if(exists($encoding)) then concat(' encoding "', $encoding, '"')  else ()};</pre>
          </section>
        else ()
    }
  </section>
  <section id="namespaces">
  {
    if(exists($namespaces)) then
      <div>
        <h2>Namespaces</h2>
        <table class="table table-bordered">
        {
          for $ns in $namespaces
          return
            <tr>
              <td>{string($ns/@prefix)}</td>
              <td>{string($ns/@uri)}</td>
            </tr>
        }
        </table>
      </div>
    else ()
  }
  </section>
  <section id="variable-summary">
  {
    if(exists($variables)) then
      <div>
        <h2>Variable Summary</h2>
        <dl>
        {
          for $variable in $variables
          let $varname := $variable/xq:uri/text()
          return <dd>
            <a href="#{$varname}">{$varname}</a>
          </dd>
        }
        </dl>
      </div>
    else()
  }
  </section>
  <section id="function-summary">
  {
    if(exists($functions)) then
      <div>
        <h2>Function Summary</h2>
        <table class="table table-bordered">
        {
          for $function in $functions
          let $name  := $function/xq:name/text()/substring-after(., ":")
          let $arity := number($function/@arity)
          return <tr>
            <!--<td>{html:function-properties($function)}</td>-->
            <td>
              <code><a href="#{$name}-{$arity}">{$name}</a>{substring-after($function/xq:signature/text(), $function/xq:name/text())}</code>
              { 
                let $description := $function/xq:comment/xq:description
                return
                  if(exists($description)) then
                    html:description-summary($description)
                  else ()
              }
            </td>
          </tr>
        }
        </table>
      </div>
    else ()
  }
  </section>
  <section id="variables">
  {
    if(exists($variables)) then
      <div class="variables">
        <h2>Variables</h2>
        {
          for $variable at $i in $variables
          let $name := $variable/xq:uri/text()
          let $type := $variable/xq:comment/xq:custom[@tag = "type"]/text()
          return <section id="{$name}" class="variable var-{$i}">
            <code>${$name}{if(exists($type)) then concat(" as ", $type) else ()}</code>
            <p>{$variable/xq:comment/xq:description/node()}</p>
          </section>
        }
      </div>
    else ()
  }
  </section>
  <section id="functions">
  {
    if(exists($functions)) then
      <div class="functions">
        <h2>Functions</h2>
        {
          for $function at $i in $functions
          let $qname  := $function/xq:name/text()
          let $name   := $qname/substring-after(., ":")
          let $arity  := string($function/@arity)
          let $params := $function/xq:parameters/xq:parameter
          let $return := $function/xq:return
          let $errors := $function/xq:comment/xq:error
          return <section class="function fn-{$i}" id="{$name}-{$arity}">
            <h3>{$name}#{$arity}</h3>
            <pre class="ace-static" ace-mode="xquery">{concat("declare", html:serialize-annotations($function/xq:annotations), if(html:is-function-updating($function)) then " updating " else " ")}function {$qname}({html:serialize-params($function/xq:parameters)})</pre>
            <p>{$function/xq:comment/xq:description/node()}</p>
            {
               if(exists($params)) then
                <section class="parameters-section">
                  <h4>Parameters</h4>
                  <ul class="parameters">
                  {
                    for $param in $params
                    return <li>
                    <code>{concat("$", $param/xq:name/text())} as {concat($param/xq:type/text(), $param/xq:type/@occurence)}</code>
                    {
                      let $variable := concat('$', $param/xq:name/text())
                      let $description := $function/xq:comment/xq:param[starts-with(./text()[1], $variable)][1]
                      let $description := if(exists($description)) then
                                            copy $d := $description
                                            modify (
                                              rename node $d as "div",
                                              let $text-node := $d/text()[starts-with(., $variable)]
                                              return
                                                replace value of node $text-node with replace($text-node, concat("\$", $param/xq:name/text()), "")
                                            )
                                            return $d
                                          else ()
                      return $description
                    } 
                    </li>
                  }
                  </ul>
                </section>
               else ()
            }
            {
              if(exists($return)) then
                <section class="returns-section">
                  <h4>Returns</h4>
                  <ul class="returns">
                    <li>
                      <code>{$return/xq:type/text()}</code>
                      <p>{$function/xq:comment/xq:return/node()}</p>
                    </li>
                  </ul>
                </section>
              else ()
            }
            {
              if(exists($errors)) then
                <section class="errors-section">
                  <h4>Errors</h4>
                  <ul class="errors">
                  {
                    for $error in $errors
                    return <li>
                    {$error/node()}
                    </li>
                  }
                  </ul>
                </section>
              else ()
            }
          </section>
        }
      </div>
    else ()
  }
  </section>
</div>)
};

declare %private function html:normalize-pre($pre as element(pre))
as element(pre)
{
  <pre>
  {$pre/attribute()}
  {serialize($pre/node(), <o:serialization-parameters></o:serialization-parameters>)}
  </pre>
};

declare %private function html:normalize($nodes as node()*)
as item()*
{
  copy $html := $nodes
  modify (
    for $node in $html//*[empty(./node()[not(. instance of attribute())]) and local-name(.) = $html:empty-tags-to-delete]
    return delete node $node,
    for $pre in $html//pre[exists(*)]
    return replace node $pre with html:normalize-pre($pre)
  )
  return $html
};

declare %private function html:text($nodes as node()*)
as xs:string?
{
  string-join( 
    for $node in $nodes
    return
      if($node instance of text()) then
        $node
      else
        html:text($node/node())
  , " ")
};

declare %private function html:description-summary($description as element(xq:description))
as element(p)
{
  let $text := html:text($description)
  let $text := if(contains($text, ".")) then concat(substring-before($text, "."), ".") else $text
  return
     <p>{$text}</p>
};

declare %private function html:serialize-params($params as element(xq:parameters)?)
as xs:string*
{
  let $params :=
    for $param in $params/xq:parameter
    return
      concat("$", $param/xq:name/text(), " as ", $param/xq:type/text(), $param/xq:type/@occurrence)
  return
    if(exists($params)) then
      concat("
    ", string-join($params, ",
    "), "
")
    else ()
};

declare %private function html:serialize-annotations($annotations as element(xq:annotations)?)
as xs:string?
{
  let $result :=
    string-join(
      let $namespaces := $annotations/ancestor::*[empty(..)]//xq:module/xq:custom[@tag = "namespaces"]/xq:namespace
      for $annotation in $annotations/xq:annotation
      let $ns := $annotation/@namespace/string(.)
      let $prefix := $annotation/@prefix/string(.)
      return
        concat("%", if(exists($prefix)) then concat($prefix, ":") else (), $annotation/@localname)
    , " ")
  return
    if($result != "") then
      concat(" ", $result)
    else
      $result
};

declare %private function html:function-properties($function as element(xq:function))
as element(span)*
{
  if(html:is-function-external($function)) then
    <span class="external">&#160;</span>
  else(),
  if(html:is-function-sequential($function)) then
    <span class="sequential">&#160;</span>
  else(),
  if(html:is-function-updating($function)) then
    <span class="updating">&#160;</span>
  else (),
  if(html:is-function-variadic($function)) then
    <span class="variadic">&#160;</span>
  else (),
  if(html:is-function-streamable($function)) then
    <span class="streamable">&#160;</span>
  else (),
  if(html:is-function-nondeterministic($function)) then
    <span class="nondeterministic">&#160;</span>
  else ()
};

declare %private function html:is-function-updating($function as element(xq:function))
as xs:boolean
{
  $function/xq:signature/text()/contains(substring-before(., $function/xq:name/text()), " updating ")
};

declare %private function html:is-function-private($function as element(xq:function))
as xs:boolean
{
  exists($function/xq:annotations/xq:annotation[@localname = "private" and @namespace = "http://www.w3.org/2005/xpath-functions"])
};

declare %private function html:is-function-nondeterministic($function as element(xq:function))
as xs:boolean
{
  exists($function//xq:annotation[@namespace = "http://www.zorba-xquery.com/annotations" and @localname = "nondeterministic"]) 
};

declare %private function html:is-function-streamable($function as element(xq:function))
as xs:boolean
{
  exists($function//xq:annotation[@namespace = "http://www.zorba-xquery.com/annotations" and @localname = "streamable"]) 
};

declare %private function html:is-function-variadic($function as element(xq:function))
as xs:boolean
{
  exists($function//xq:annotation[@namespace = "http://www.zorba-xquery.com/annotations" and @localname = "variadic"]) 
};

declare %private function html:is-function-sequential($function as element(xq:function))
as xs:boolean
{
  exists($function//xq:annotation[@namespace = "http://www.zorba-xquery.com/annotations" and @localname = "sequential"]) 
};

declare %private function html:is-function-external($function as element(xq:function))
as xs:boolean
{
  $function/xq:signature/text()/ends-with(., " external")
};
