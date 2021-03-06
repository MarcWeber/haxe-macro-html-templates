// import macro.HTMLTemplate;
import haxe.macro.Expr;
import haxe.macro.Context;
import mw.HTMLTemplate;

class KnownImages {
  static public function imageHTML(ctx:Dynamic, bx:String, x:Dynamic){
    return "<tag>";
  }
}

class TestHTMLParser {

  macro static function test(nr:ExprOf<Int>, template:ExprOf<String>, expected:ExprOf<String>):Expr {
    return macro {
      var r = mw.HTMLTemplate.str($template);
      if (r == $expected){
        Sys.println($nr+" ok");
      } else {
        Sys.println("=== ERROR: "+$nr);
        Sys.println("expected: "+$expected);
        Sys.println("got     : "+r);
      }
    }
  }

  static public function test_some_macro_stuff() {
    function test(name, fun, s){
      var ps:ParserState = {
        s: s,
        i: 0,
        pos: null,
        available_filters: []
      }
      if (!fun(ps))
        throw '${name} returned false';

      if (ps.i != s.length -1)
        throw '${name} failed to parse whole string, ${ps.i}';

      var ps:ParserState = {
           s: s,
           i: 0,
        pos: null,
        available_filters: []
      }

      // test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "\"\"+2+3+4 ");
    }


    test("walk_str", mw.TemplateParser.walk_str, "'abc' ");
    test("walk_str", mw.TemplateParser.walk_str, "\"abc\" ");

    test("walk_id", mw.TemplateParser.walk_id, "abc ");
    test("walk_id", mw.TemplateParser.walk_id, "245 ");
    test("walk_id", mw.TemplateParser.walk_id, "Foo234_ ");
    test("walk_struct", mw.TemplateParser.walk_struct, "{abc:\"foo\"} ");

    test("walk_parenthesis", mw.TemplateParser.walk_parenthesis, "(2) ");
    test("walk_parenthesis", mw.TemplateParser.walk_parenthesis, "(2 + 4) ");
    test("walk_parenthesis", mw.TemplateParser.walk_parenthesis, "('abc') ");
    test("walk_parenthesis", mw.TemplateParser.walk_parenthesis, "(abc.foo) ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "\"\"+2+3+4 ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "abc(foo) ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "foo.Bar(2) ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "foo.Bar(2, 3) ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "foo.bar.x(abc, foo) ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "f.html() ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, false) , "KnownImages.imageHTML(ctx,b,\"h-25\") ");
    test("walk_haxe_expr", function(s) return  mw.TemplateParser.walk_haxe_expr(s, false, true) , "(u != null) ");

  }

  static function main() {
    test_some_macro_stuff();

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
 
     test(9, "#abc(attr=(\"\"+2+3+4))", "<div id=\"abc\" attr=\"234\"></div>");
     test(9, "#abc(attr='xyz')", "<div id=\"abc\" attr=\"xyz\"></div>");
     test(10, "#abc(attr='xyz')", "<div id=\"abc\" attr=\"xyz\"></div>");
     test(11, "#abc(attr=value )", "<div id=\"abc\" attr=\"X\"></div>");
     test(12, "#abc({attr: \"X\"})", "<div id=\"abc\" attr=\"X\"></div>");
     test(13, "#abc(attr=value)zdf", "<div id=\"abc\" attr=\"X\">zdf</div>");
     test(14, "#abc(attr=value)='<zdf>'", "<div id=\"abc\" attr=\"X\">&lt;zdf&gt;</div>");
     test(15, "#abc(attr=value)!='<zdf>'", "<div id=\"abc\" attr=\"X\"><zdf></div>");
     test(16, "
        %div
        %div
      ","<div></div> <div></div>");
 
      // trace(TemplateParser.parse_template(null, "
      //   #abc(attr=$value)
      //     #inner
      //       #inner2"));
 
      test(17, "
        #abc(attr=value)
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
          %div=(''+i)
      ", "<div>1</div><div>2</div><div>3</div>");
 

       // without space
      test(24, "
        :for(i in [1,2,3])
          %div=(''+i)
      ", "<div>1</div><div>2</div><div>3</div>");
 
 
      test(25, "
        :javascript
          alert('abc');
      ", "<script type='text/javascript'>//<![CDATA[alert('abc');//]]></script>");
 
      test(26, "
        :css
          div {
            height;
          }
      ", "<style type='text/css'>//<![CDATA[div {   height; }//]]></style>");
 
      test(27, "
        %div
          -#
            multi line
            comment
      ", "<div></div>");
 
      test(28, "
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
 
      var value = "first";
      test(29, "
        :switch (value)
        :case \"first\":
          %div first_text
        :case \"second\":
          %div second_text
        :default:
      ", "<div>first_text</div> ");
 
      test(30, "
        :switch (\"none\")
        :case \"first\":
          %div first_text
        :default:
          %div default_text
      ", "<div>default_text</div> ");
 
 
      test(31, "
      :for (i in [1,2,3])
        %div
          some
          %ul
            %li.list
              %a(href=\"link\")
      ", "<div>some<ul><li class=\"list\"><a href=\"link\"></a> </li> </ul> </div> <div>some<ul><li class=\"list\"><a href=\"link\"></a> </li> </ul> </div> <div>some<ul><li class=\"list\"><a href=\"link\"></a> </li> </ul> </div> ");

      test(32, "
      :for (i in [1,2,3])
        !=i
      ", "123");


      var args = ["1","2","3"];
      test(32, "
      #id_value
        :for (i in args)
          !=i
      ", '<div id="id_value">123</div>');

      // what about this space?
      test(33, "
      %div

      %div
      ", "<div></div> <div></div>");

      // test(34, "
      //     :for(u in users)
      //       :if (u.queenFlavour() != null)
      //         =u.queenFlavour()
      // ", "");

      var brand_images = ["1","2"];
      var ctx = null;
      test(34, "
      :for (bx in brand_images)
        !=KnownImages.imageHTML(ctx, bx, 'h-25')
      ", "");


      var r = mw.HTMLTemplate.str("
      :for (bx in brand_images)
        !=KnownImages.imageHTML(ctx, bx, 'h-25')
      ");


    return mw.HTMLTemplate.str("
      :for (bx in brand_images)
        !=KnownImages.imageHTML(ctx, bx, 'h-25')
    ");
 
      /* expected runtime failure, location should point to d.x.y */
      trace("EXPECTED FAILURE, trace should point to d.x.y");
      var d = null;
      test(34, "
        %div
          =d.x.y
        %div
      ", "failure expected");
 
  }

  static public function sample() {
    // Example illustrating all features.
    // If you don't know this style have a look at haml-lang.org to get an idea.

//     var html = HTMLTemplate.str('
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
