using System;
using System.Text.RegularExpressions;
using UnityEngine;
using UnityEditor;

public class ShowIfPropertyConditionsDrawer : MaterialPropertyDrawer
{
    public struct PropertyCondition
    {
        public string property;
        public string comparer;
        public float value;

        public PropertyCondition(string property, string comparer, float value)
        {
            this.property = property;
            this.comparer = comparer?.ToLower();
            this.value = value;
        }

        public bool CheckCondition(Material mat)
        {
            if (property == null) return true; //未设置则不做判断
            var matProValue = mat.GetFloat(property);
            switch (comparer)
            {
                case "equal":
                    return matProValue == value;
                case "notequal":
                    return matProValue != value;
                case "less":
                    return matProValue < value;
                case "greater":
                    return matProValue > value;
                default:
                    Debug.LogWarning($"comparer {comparer} is not identified.");
                    return false;
            }
        }
    }

    protected PropertyCondition[] argValue;
    bool bElementVisble;
    private float propertyHeight = 0;

    public ShowIfPropertyConditionsDrawer(string property, string comparer, float value) : this(property, comparer,
        value, null, null, 0, null)
    {
    }

    public ShowIfPropertyConditionsDrawer(string property, string comparer, float value,
        string property2 = null, string comparer2 = null, float value2 = 0) : this(property, comparer,
        value, property2, comparer2, value2, null)
    {
    }

    public ShowIfPropertyConditionsDrawer(string property, string comparer, float value,
        string property2 = null, string comparer2 = null, float value2 = 0,
        string property3 = null, string comparer3 = null, float value3 = 0)
    {
        argValue = new PropertyCondition[]
        {
            new PropertyCondition(property, comparer, value),
            new PropertyCondition(property2, comparer2, value2),
            new PropertyCondition(property3, comparer3, value3)
        };
    }

    public override void OnGUI(Rect position, MaterialProperty prop, string label, MaterialEditor editor)
    {
        propertyHeight = 0;
        bElementVisble = true;
        int validCount = 0;
        for (int i = 0; i < editor.targets.Length; i++)
        {
            Material mat = editor.targets[i] as Material;
            if (mat != null)
            {
                for (int j = 0; j < argValue.Length; j++)
                {
                    bElementVisble &= argValue[j].CheckCondition(mat);
                    if (argValue[j].property != null)
                        validCount++;
                }
            }
        }

        if (bElementVisble)
        {
            var shader = ((Material) editor.target).shader;
            var propertyIndex = shader.FindPropertyIndex(prop.name);
            if (propertyIndex >= 0)
            {
                var attrs = shader.GetPropertyAttributes(propertyIndex);
                foreach (var attr in attrs)
                {
                    if (attr.Contains("ShowIf")) continue;

                    MaterialPropertyDrawer drawer = GetShaderPropertyDrawer(attr, out var deco);

                    if (!deco && drawer != null)
                    {
                        for (int i = 0; i < validCount; i++)
                            EditorGUI.indentLevel++;
                        drawer.OnGUI(position, prop, new GUIContent(label), editor);
                        for (int i = 0; i < validCount; i++)
                            EditorGUI.indentLevel--;
                        propertyHeight = drawer.GetPropertyHeight(prop, label, editor);
                        return;
                    }
                }
            }

            for (int i = 0; i < validCount; i++)
                EditorGUI.indentLevel++;
            editor.DefaultShaderProperty(prop, label);
            for (int i = 0; i < validCount; i++)
                EditorGUI.indentLevel--;
        }
    }

    public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
    {
        return propertyHeight;
    }


    public static MaterialPropertyDrawer GetShaderPropertyDrawer(string attrib, out bool isDecorator)
    {
        isDecorator = false;

        string className = attrib;
        string args = string.Empty;
        Match match = Regex.Match(attrib, @"(\w+)\s*\((.*)\)");
        if (match.Success)
        {
            className = match.Groups[1].Value;
            args = match.Groups[2].Value.Trim();
        }

        //Debug.Log ("looking for class " + className + " args '" + args + "'");
        foreach (var klass in TypeCache.GetTypesDerivedFrom<MaterialPropertyDrawer>())
        {
            // When you write [Foo] in shader, get Foo, FooDrawer, MaterialFooDrawer,
            // FooDecorator or MaterialFooDecorator class;
            // "kind of" similar to how C# does attributes.

            //@TODO: namespaces?
            if (klass.Name == className ||
                klass.Name == className + "Drawer" ||
                klass.Name == "Material" + className + "Drawer" ||
                klass.Name == className + "Decorator" ||
                klass.Name == "Material" + className + "Decorator")
            {
                try
                {
                    isDecorator = klass.Name.EndsWith("Decorator");
                    return CreatePropertyDrawer(klass, args);
                }
                catch (Exception)
                {
                    Debug.LogWarningFormat("Failed to create material drawer {0} with arguments '{1}'", className,
                        args);
                    return null;
                }
            }
        }

        return null;
    }

    public static MaterialPropertyDrawer CreatePropertyDrawer(Type klass, string argsText)
    {
        // no args -> default constructor
        if (string.IsNullOrEmpty(argsText))
            return Activator.CreateInstance(klass) as MaterialPropertyDrawer;

        // split the argument list by commas
        string[] argStrings = argsText.Split(',');
        var args = new object[argStrings.Length];
        for (var i = 0; i < argStrings.Length; ++i)
        {
            float f;
            string arg = argStrings[i].Trim();

            // if can parse as a float, use the float; otherwise pass the string
            if (float.TryParse(arg, System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture.NumberFormat, out f))
            {
                args[i] = f;
            }
            else
            {
                args[i] = arg;
            }
        }

        return Activator.CreateInstance(klass, args) as MaterialPropertyDrawer;
    }
}
