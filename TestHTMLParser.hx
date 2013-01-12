// import macro.HTMLTemplate;
import haxe.macro.Expr;
import haxe.macro.Context;

class TestHTMLParser {

  @:macro static function test(nr:ExprOf<Int>, template:ExprOf<String>, expected:ExprOf<String>):Expr {
    return macro {
      var r = mw.HTMLTemplate.haml_like_str($template);
      if (r == $expected){
        Sys.println("ok");
      } else {
        Sys.println("=== ERROR: "+$nr);
        Sys.println("expected: "+$expected);
        Sys.println("got     : "+r);
      }
    }
  }

  static function main() {

      // ../haxe-mw-extensions/lib/ExprExtensions.hx:5: { expr => EBlock([{ expr => EFor({ expr => EIn({ expr => EConst(CIdent(x)), pos => #pos(Test.hx|544 col 12| },{ expr => EArrayDecl([]), pos => #pos(Test.hx:544: characters 17-19) }), pos => #pos(Test.hx:544: characters 12-19) },{ expr => EConst(CIdent(true)), pos => #pos(Test.hx:544: characters 21-25) }), pos => #pos(Test.hx:544: characters 8-25) }]), pos => #pos(Test.hx:543: lines 543-545) }

  var value = "X";
    // ExprExtensions.trace({ for(x in []) true; });

    test(1, "
        %div", "<div></div>");
    test(2, "
    %div>
    ", "<div></div>");

    test(3, "%div", "<div></div>");
    test(4, "%div.abc", "<div class=\"abc\"></div>");
    test(5, ".abc", "<div class=\"abc\"></div>");
    test(6, "%div.a.b", "<div class=\"a b\"></div>");
    test(7, "%div#abc", "<div id=\"abc\"></div>");
    test(8, "#abc", "<div id=\"abc\"></div>");

    test(9, "#abc(attr='xyz')", "<div id=\"abc\" attr=\"xyz\"></div>");
    test(10, "#abc(attr='xyz')", "<div id=\"abc\" attr=\"xyz\"></div>");
    test(11, "#abc(attr=$value )", "<div id=\"abc\" attr=\"X\"></div>");
    test(12, "#abc(${attr: \"X\"})", "<div id=\"abc\" attr=\"X\"></div>");
    test(13, "#abc(attr=$value)zdf", "<div id=\"abc\" attr=\"X\">zdf</div>");
    test(14, "#abc(attr=$value)='<zdf>'", "<div id=\"abc\" attr=\"X\">&lt;zdf&gt;</div>");
    test(15, "#abc(attr=$value)!='<zdf>'", "<div id=\"abc\" attr=\"X\"><zdf></div>");
    test(16, "
      %div
      %div
    ","<div></div> <div></div>");

    // trace(TemplateParser.parse_template(null, "
    //   #abc(attr=$value)
    //     #inner
    //       #inner2"));

    test(17, "
      #abc(attr=$value)
        #inner
          .inner2
    ", "<div id=\"abc\" attr=\"X\"><div id=\"inner\"><div class=\"inner2\"></div> </div> </div>");

    test(18, "
      %div
        The brown fox is running ${'<here>'}
        and !{'<there>'}
    ", "<div>The brown fox is running &lt;here&gt; and <there></div>");
    test(19, "
      :if (true)
        %div
    ", "<div></div> ");
    test(20, "
      :if (false)
        %div
    ", "");

    test(21, "
      :if (true)
        %div true
      :else
        %div false
    ", "<div>true</div> ");


    // trace(TemplateParser.parse_template(null, "
    //   :if (true)
    //     %div true
    //   :else
    //     %div false
    // "));

    test(22, "
      :if (false)
        %div true
      :else
        %div false
    ", "<div>false</div> ");


    // trace(TemplateParser.parse_template(null, "
    //   %div
    //     The brown fox is running ${'<here>'}
    //     and !{'<there>'}
    // "));


     // mind the > omitting the space after the tag
    test(23, "
      :for (i in [1,2,3])
        %div>=(''+i)
    ", "<div>1</div><div>2</div><div>3</div>");


    test(24, "
      :javascript
        alert('abc');
    ", "<script type='text/javascript'>//<![CDATA[alert('abc');//]]></script>");

    test(25, "
      :css
        div {
          height;
        }
    ", "<style type='text/css'>//<![CDATA[div {   height; }//]]></style>");

    test(25, "
      %div
        -#
          multi line
          comment
    ", "<div></div>");

    test(26, "
      %div
        -# single line comment
      %div
    ", "<div></div> <div></div>");

    /* expected compilation failure, error location should be on bad_method */
    // var m = new Hash();
    // test(26, "
    //   %div
    //     =m.bad_method()
    //   %div
    // ", "failure expected");
      


    /* expected runtime failure, location should point to d.x.y */
    trace("EXPECTED FAILURE, trace should point to d.x.y");
    var d = null;
    test(26, "
      %div
        =d.x.y
      %div
    ", "failure expected");

  }

  static public function sample() {
    // Example illustrating all features.
    // If you don't know this style have a look at haml-lang.org to get an idea.

//     var html = HTMLTemplate.haml_like_str('
//     %div(class="first_level")%div.second_level foo
//     %p
//       some multiline text
//       with quoted expression ${"haxe expression"} and
//       an unquoted expression !{"<b>bold</b>"}

//       Thus a table can be written pretty easily:

//     %table%tr
//       %td foo
//       %td bar

//     #id_shorcut
//       This will expand to <div id="id_shorcut"></div>

//     :if (True)
//       .fine everything is fine
//     :else
//       .bad something went wrong

//     -# of course comments are supported
//     -#
//       and more haxe expressions
//       like a for loop - and dynamic tags are supported:
//     :for (i in [1,2,3])
//       %div(${class: "i_is_"+i} color=${i})=i
//     ')();

//     trace(html);
  }
  
}
